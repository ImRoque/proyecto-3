import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/medio_entrega.dart';

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
    final http.Response respuesta;
    try {
      respuesta = await _cliente
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(tiempoLimite);
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
