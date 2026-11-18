import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/medio_entrega.dart';
import '../models/pedido.dart';
import '../models/tipo_servicio.dart';

/// Error de una llamada al API, con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  const ApiException(this.mensaje, {this.codigoHttp, this.codigoError});

  /// Texto claro para mostrar en pantalla.
  final String mensaje;

  /// Código HTTP de la respuesta, si hubo respuesta.
  final int? codigoHttp;

  /// Valor del campo `error` del formato único de docs/api.md, si vino.
  final String? codigoError;

  @override
  String toString() => 'ApiException($codigoHttp, $codigoError): $mensaje';
}

/// Único lugar de la app que hace llamadas HTTP.
///
/// Todas las rutas son relativas a la URL base del gateway (ver `config.dart`).
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? cliente,
    this.tiempoLimite = const Duration(seconds: 5),
  }) : _cliente = cliente ?? http.Client();

  /// URL base del gateway, sin `/` al final.
  final String baseUrl;
  final http.Client _cliente;

  /// Tiempo máximo de espera de cada llamada.
  final Duration tiempoLimite;

  /// Hace `GET` a [ruta] (por ejemplo `/api/catalogo/health/`) y devuelve el JSON.
  ///
  /// [parametros] se agregan como parámetros de consulta (`?q=...`), ya codificados.
  ///
  /// Lanza [ApiException] si no hay conexión, se agota el tiempo, el servicio no
  /// está disponible (503) o la respuesta no es exitosa.
  Future<Map<String, dynamic>> getJson(String ruta, {Map<String, String>? parametros}) async {
    var uri = Uri.parse('$baseUrl$ruta');
    if (parametros != null && parametros.isNotEmpty) {
      uri = uri.replace(queryParameters: parametros);
    }
    return _enviar(() => _cliente.get(uri, headers: const {'Accept': 'application/json'}));
  }

  /// Hace `POST` a [ruta] con [cuerpo] en JSON y devuelve el JSON de respuesta.
  ///
  /// [encabezados] se agregan a los de JSON (por ejemplo `Idempotency-Key`).
  /// Lanza [ApiException] igual que [getJson].
  Future<Map<String, dynamic>> _postJson(
    String ruta,
    Map<String, dynamic> cuerpo, {
    Map<String, String> encabezados = const {},
  }) {
    final uri = Uri.parse('$baseUrl$ruta');
    final todos = {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      ...encabezados,
    };
    return _enviar(() => _cliente.post(uri, headers: todos, body: utf8.encode(jsonEncode(cuerpo))));
  }

  /// Ejecuta la llamada con tiempo límite y convierte los fallos de red en [ApiException].
  Future<Map<String, dynamic>> _enviar(Future<http.Response> Function() llamada) async {
    final http.Response respuesta;
    try {
      respuesta = await llamada().timeout(tiempoLimite);
    } on TimeoutException {
      throw ApiException('El servidor tardó más de ${tiempoLimite.inSeconds} s en responder.');
    } on http.ClientException {
      throw const ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión y la URL del API.',
      );
    }
    return _procesar(respuesta);
  }

  Map<String, dynamic> _procesar(http.Response respuesta) {
    final cuerpo = _decodificar(respuesta);
    final codigo = respuesta.statusCode;

    if (codigo >= 200 && codigo < 300) {
      if (cuerpo == null) {
        throw ApiException('El servidor respondió con un formato inesperado.', codigoHttp: codigo);
      }
      return cuerpo;
    }

    final codigoError = cuerpo?['error'] as String?;
    final detalle = cuerpo?['detalle'] as String?;

    if (codigo == 503) {
      throw ApiException(
        detalle ?? 'El servicio no está disponible en este momento.',
        codigoHttp: codigo,
        codigoError: codigoError ?? 'servicio_no_disponible',
      );
    }

    throw ApiException(
      detalle ?? 'El servidor respondió con un error ($codigo).',
      codigoHttp: codigo,
      codigoError: codigoError,
    );
  }

  /// Decodifica el cuerpo como UTF-8 y JSON; `null` si no es un objeto JSON.
  Map<String, dynamic>? _decodificar(http.Response respuesta) {
    try {
      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      return datos is Map<String, dynamic> ? datos : null;
    } on FormatException {
      return null;
    }
  }

  // ---------- Catálogo (docs/api.md, sección "Catálogo") ----------

  /// `GET /api/catalogo/medios/?q=<texto>`. Sin [q] (o vacío) devuelve todos los medios.
  Future<List<MedioEntrega>> listarMedios({String? q}) async {
    final texto = q?.trim() ?? '';
    final datos = await getJson(
      '/api/catalogo/medios/',
      parametros: texto.isEmpty ? null : {'q': texto},
    );
    final medios = datos['medios'];
    if (medios is! List) {
      throw const ApiException('El servidor respondió con un formato inesperado.');
    }
    return _convertir(
      () => [for (final medio in medios) MedioEntrega.fromJson(medio as Map<String, dynamic>)],
    );
  }

  /// `GET /api/catalogo/medios/<clave>/`. Si no existe, lanza [ApiException] con
  /// `codigoHttp` 404 y `codigoError` `no_encontrado`.
  Future<MedioEntrega> obtenerMedio(String clave) async {
    final datos = await getJson('/api/catalogo/medios/${Uri.encodeComponent(clave)}/');
    return _convertir(() => MedioEntrega.fromJson(datos));
  }

  /// `GET /api/catalogo/tipos-servicio/`.
  Future<List<TipoServicio>> listarTiposServicio() async {
    final datos = await getJson('/api/catalogo/tipos-servicio/');
    final tipos = datos['tipos_servicio'];
    if (tipos is! List) {
      throw const ApiException('El servidor respondió con un formato inesperado.');
    }
    return _convertir(
      () => [for (final tipo in tipos) TipoServicio.fromJson(tipo as Map<String, dynamic>)],
    );
  }

  // ---------- Pedidos (docs/api.md, sección "Pedidos") ----------

  /// `POST /api/pedidos/` con el encabezado `Idempotency-Key`.
  ///
  /// Quien llama debe reutilizar la misma [idempotencyKey] en todos los reintentos del mismo
  /// envío: si el servidor ya lo registró, responde `200` con el mismo pedido (mismo folio).
  /// Los errores del contrato (`datos_invalidos`, `medio_no_apto`,
  /// `idempotency_key_reutilizada`, `servicio_no_disponible`) llegan en
  /// [ApiException.codigoError].
  Future<Pedido> registrarPedido(
    SolicitudPedido solicitud, {
    required String idempotencyKey,
  }) async {
    final datos = await _postJson(
      '/api/pedidos/',
      solicitud.toJson(),
      encabezados: {'Idempotency-Key': idempotencyKey},
    );
    return _convertir(() => Pedido.fromJson(datos));
  }

  /// `GET /api/pedidos/<folio>/`. Si no existe, lanza [ApiException] con `codigoHttp` 404.
  Future<PedidoResumen> consultarPedido(String folio) async {
    final datos = await getJson('/api/pedidos/${Uri.encodeComponent(folio)}/');
    return _convertir(() => PedidoResumen.fromJson(datos));
  }

  /// Convierte errores de formato del JSON en [ApiException] con un mensaje claro.
  T _convertir<T>(T Function() conversion) {
    try {
      return conversion();
    } on FormatException {
      throw const ApiException('El servidor respondió con un formato inesperado.');
    } on TypeError {
      throw const ApiException('El servidor respondió con un formato inesperado.');
    }
  }

  /// Libera la conexión. Llamar cuando ya no se use el cliente.
  void cerrar() => _cliente.close();
}
