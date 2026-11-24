import 'package:flutter/material.dart';

import '../models/medio_entrega.dart';
import '../models/pedido.dart';
import '../models/tipo_servicio.dart';
import '../services/api_client.dart';
import '../services/aviso_error.dart';
import '../services/idempotencia.dart';
import 'catalogo_screen.dart' show formatearNumero, iconoMedio;
import 'confirmacion_screen.dart';

/// Máximo de caracteres de origen y destino (docs/api.md).
const int textoMaxCaracteres = 200;

/// Formulario para registrar un envío nuevo.
///
/// Evita pedidos duplicados por doble toque de dos formas:
/// - El botón Confirmar se deshabilita mientras se espera la respuesta.
/// - Cada formulario tiene una `Idempotency-Key` que se reutiliza en todos los reintentos y solo
///   se renueva cuando el pedido se registró con éxito. Si el servidor ya lo registró, devuelve
///   el mismo folio.
class NuevoEnvioScreen extends StatefulWidget {
  const NuevoEnvioScreen({super.key, required this.api, this.generarClave = generarUuidV4});

  final ApiClient api;

  /// Genera la `Idempotency-Key`. Se puede sustituir en pruebas.
  final String Function() generarClave;

  @override
  State<NuevoEnvioScreen> createState() => _NuevoEnvioScreenState();
}

class _NuevoEnvioScreenState extends State<NuevoEnvioScreen> {
  final _formulario = GlobalKey<FormState>();
  final _origen = TextEditingController();
  final _destino = TextEditingController();
  final _distancia = TextEditingController();
  final _peso = TextEditingController();
  final _largo = TextEditingController();
  final _ancho = TextEditingController();
  final _alto = TextEditingController();

  /// Peso y distancia se revalidan al cambiar de medio (dependen de su capacidad).
  final _campoPeso = GlobalKey<FormFieldState<String>>();
  final _campoDistancia = GlobalKey<FormFieldState<String>>();

  bool _urgente = false;
  bool _seguro = false;
  DateTime? _fechaLimite;
  String? _medio;
  String? _tipoServicio;

  /// Clave del envío en curso: la misma en cada reintento, nueva tras un registro exitoso.
  late String _idempotencyKey = widget.generarClave();

  /// Cambia al reiniciar el formulario para que los campos con valor inicial se reconstruyan.
  int _version = 0;

  List<MedioEntrega>? _medios;
  List<TipoServicio>? _tipos;
  AvisoError? _errorCatalogo;

  bool _enviando = false;
  ApiException? _errorEnvio;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    for (final c in [_origen, _destino, _distancia, _peso, _largo, _ancho, _alto]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarCatalogo() async {
    setState(() {
      _medios = null;
      _tipos = null;
      _errorCatalogo = null;
    });
    try {
      final resultados = await Future.wait([
        widget.api.listarMedios(),
        widget.api.listarTiposServicio(),
      ]);
      if (!mounted) return;
      setState(() {
        _medios = resultados[0] as List<MedioEntrega>;
        _tipos = resultados[1] as List<TipoServicio>;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorCatalogo = AvisoError.de(e, funcion: 'El catálogo'));
    }
  }

  MedioEntrega? get _medioElegido {
    final medios = _medios;
    if (medios == null) return null;
    for (final medio in medios) {
      if (medio.clave == _medio) return medio;
    }
    return null;
  }

  SolicitudPedido _solicitud() => SolicitudPedido(
    origen: _origen.text.trim(),
    destino: _destino.text.trim(),
    distanciaKm: _numero(_distancia.text)!,
    pesoKg: _numero(_peso.text)!,
    dimensiones: Dimensiones(
      largo: _numero(_largo.text)!,
      ancho: _numero(_ancho.text)!,
      alto: _numero(_alto.text)!,
    ),
    urgente: _urgente,
    seguro: _seguro,
    fechaLimite: _fechaLimite!,
    medio: _medio!,
    tipoServicio: _tipoServicio!,
  );

  Future<void> _confirmar() async {
    // Dos toques en el mismo cuadro llegan antes de que el botón se redibuje deshabilitado.
    if (_enviando) return;
    if (!(_formulario.currentState?.validate() ?? false)) return;

    setState(() {
      _enviando = true;
      _errorEnvio = null;
    });
    try {
      final pedido = await widget.api.registrarPedido(
        _solicitud(),
        idempotencyKey: _idempotencyKey,
      );
      if (!mounted) return;
      // Éxito: el siguiente envío es otro pedido, con otra clave.
      _reiniciar();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConfirmacionScreen(api: widget.api, pedido: pedido),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _errorEnvio = e;
      });
    }
  }

  /// Limpia el formulario y genera una clave nueva.
  void _reiniciar() {
    for (final c in [_origen, _destino, _distancia, _peso, _largo, _ancho, _alto]) {
      c.clear();
    }
    setState(() {
      _urgente = false;
      _seguro = false;
      _fechaLimite = null;
      _medio = null;
      _tipoServicio = null;
      _enviando = false;
      _errorEnvio = null;
      _idempotencyKey = widget.generarClave();
      _version++;
    });
  }

  /// La clave ya se usó con otros datos: se empieza un envío nuevo a propósito.
  void _empezarEnvioNuevo() {
    setState(() {
      _idempotencyKey = widget.generarClave();
      _errorEnvio = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo envío')),
      body: _cuerpo(context),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final errorCatalogo = _errorCatalogo;
    if (errorCatalogo != null) {
      return _AvisoCatalogo(aviso: errorCatalogo, alReintentar: _cargarCatalogo);
    }
    final medios = _medios;
    final tipos = _tipos;
    if (medios == null || tipos == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formulario,
      child: ListView(
        key: ValueKey(_version),
        padding: const EdgeInsets.all(16),
        children: [
          _campoTexto(_origen, 'Origen', 'Calle, número, colonia y ciudad'),
          _campoTexto(_destino, 'Destino', 'Calle, número, colonia y ciudad'),
          Row(
            children: [
              Expanded(
                child: _campoNumero(
                  _distancia,
                  'Distancia',
                  'km',
                  _validarDistancia,
                  _campoDistancia,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _campoNumero(_peso, 'Peso', 'kg', _validarPeso, _campoPeso)),
            ],
          ),
          Text('Dimensiones (cm)', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _campoNumero(_largo, 'Largo', 'cm')),
              const SizedBox(width: 8),
              Expanded(child: _campoNumero(_ancho, 'Ancho', 'cm')),
              const SizedBox(width: 8),
              Expanded(child: _campoNumero(_alto, 'Alto', 'cm')),
            ],
          ),
          _CampoFecha(
            valor: _fechaLimite,
            habilitado: !_enviando,
            alCambiar: (fecha) => setState(() => _fechaLimite = fecha),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _medio,
            isExpanded: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(
              labelText: 'Medio de entrega',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final medio in medios)
                DropdownMenuItem(
                  value: medio.clave,
                  child: Row(
                    children: [
                      Icon(iconoMedio(medio.clave), size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${medio.nombre} · hasta ${formatearNumero(medio.pesoMaxKg)} kg, '
                          '${formatearNumero(medio.distanciaMaxKm)} km',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: _enviando
                ? null
                : (valor) {
                    setState(() => _medio = valor);
                    // Revalida peso y distancia contra la capacidad del medio nuevo, solo si ya
                    // tienen algo escrito, para no marcar en rojo campos que aún no se llenan.
                    for (final campo in [_campoPeso, _campoDistancia]) {
                      if (campo.currentState?.value?.isNotEmpty ?? false) {
                        campo.currentState!.validate();
                      }
                    }
                  },
            validator: (valor) => valor == null ? 'Elige un medio de entrega' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _tipoServicio,
            isExpanded: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(
              labelText: 'Tipo de servicio',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final tipo in tipos)
                DropdownMenuItem(
                  value: tipo.clave,
                  child: Text(
                    '${tipo.nombre} · ${tipo.descripcion}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _enviando ? null : (valor) => setState(() => _tipoServicio = valor),
            validator: (valor) => valor == null ? 'Elige un tipo de servicio' : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Urgente'),
            value: _urgente,
            onChanged: _enviando ? null : (v) => setState(() => _urgente = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Con seguro'),
            subtitle: const Text('Agrega 10 % al costo'),
            value: _seguro,
            onChanged: _enviando ? null : (v) => setState(() => _seguro = v),
          ),
          if (_errorEnvio case final error?) ...[
            const SizedBox(height: 8),
            _AvisoEnvio(error: error, alReintentar: _confirmar, alEmpezarNuevo: _empezarEnvioNuevo),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('confirmar_envio'),
            onPressed: _enviando ? null : _confirmar,
            icon: _enviando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_enviando ? 'Registrando…' : 'Confirmar envío'),
          ),
        ],
      ),
    );
  }

  Widget _campoTexto(TextEditingController controlador, String etiqueta, String ayuda) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controlador,
        enabled: !_enviando,
        maxLength: textoMaxCaracteres,
        decoration: InputDecoration(
          labelText: etiqueta,
          hintText: ayuda,
          counterText: '',
          border: const OutlineInputBorder(),
        ),
        validator: (valor) =>
            (valor == null || valor.trim().isEmpty) ? 'Escribe el ${etiqueta.toLowerCase()}' : null,
      ),
    );
  }

  Widget _campoNumero(
    TextEditingController controlador,
    String etiqueta,
    String unidad, [
    String? Function(double valor)? validarExtra,
    Key? clave,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: clave,
        controller: controlador,
        enabled: !_enviando,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: etiqueta,
          suffixText: unidad,
          border: const OutlineInputBorder(),
        ),
        validator: (texto) {
          final valor = _numero(texto ?? '');
          if (valor == null || valor <= 0) return 'Mayor que 0';
          return validarExtra?.call(valor);
        },
      ),
    );
  }

  String? _validarPeso(double peso) {
    final medio = _medioElegido;
    if (medio != null && peso > medio.pesoMaxKg) {
      return '${medio.nombre}: máx. ${formatearNumero(medio.pesoMaxKg)} kg';
    }
    return null;
  }

  String? _validarDistancia(double distancia) {
    final medio = _medioElegido;
    if (medio != null && distancia > medio.distanciaMaxKm) {
      return '${medio.nombre}: máx. ${formatearNumero(medio.distanciaMaxKm)} km';
    }
    return null;
  }
}

/// Convierte el texto en número; acepta coma decimal. `null` si no es un número.
double? _numero(String texto) {
  final valor = double.tryParse(texto.trim().replaceAll(',', '.'));
  return (valor == null || !valor.isFinite) ? null : valor;
}

/// Fecha límite con selector de calendario. No permite fechas anteriores a hoy.
class _CampoFecha extends FormField<DateTime> {
  _CampoFecha({
    required DateTime? valor,
    required bool habilitado,
    required ValueChanged<DateTime> alCambiar,
  }) : super(
         initialValue: valor,
         validator: (fecha) => fecha == null ? 'Elige la fecha límite' : null,
         builder: (campo) {
           final hoy = DateUtils.dateOnly(DateTime.now());
           final fecha = campo.value;
           return InkWell(
             onTap: !habilitado
                 ? null
                 : () async {
                     final elegida = await showDatePicker(
                       context: campo.context,
                       initialDate: fecha ?? hoy,
                       firstDate: hoy,
                       lastDate: hoy.add(const Duration(days: 365)),
                     );
                     if (elegida != null) {
                       campo.didChange(elegida);
                       alCambiar(elegida);
                     }
                   },
             child: InputDecorator(
               decoration: InputDecoration(
                 labelText: 'Fecha límite',
                 border: const OutlineInputBorder(),
                 suffixIcon: const Icon(Icons.calendar_today),
                 errorText: campo.errorText,
                 enabled: habilitado,
               ),
               child: Text(fecha == null ? 'Sin elegir' : formatearFecha(fecha)),
             ),
           );
         },
       );
}

/// Error al registrar: mensaje del servidor y la acción que corresponde.
class _AvisoEnvio extends StatelessWidget {
  const _AvisoEnvio({
    required this.error,
    required this.alReintentar,
    required this.alEmpezarNuevo,
  });

  final ApiException error;
  final VoidCallback alReintentar;
  final VoidCallback alEmpezarNuevo;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final claveReutilizada = error.codigoError == 'idempotency_key_reutilizada';
    final aviso = AvisoError.de(error, funcion: 'El registro de envíos');
    // Sin conexión, sin respuesta a tiempo o con 503 se reintenta tal cual, con la misma
    // Idempotency-Key; con 400 hay que corregir datos.
    final puedeReintentar = !claveReutilizada && aviso.reintentable;
    final String mensaje;
    if (claveReutilizada) {
      mensaje =
          'Este envío ya se registró con otros datos. Si quieres mandar estos datos '
          'como un pedido nuevo, empieza un envío nuevo.';
    } else if (error.tipo == TipoError.datosInvalidos) {
      mensaje = '${aviso.mensaje}\nCorrige el dato y vuelve a confirmar.';
    } else if (puedeReintentar) {
      mensaje =
          '${aviso.mensaje}\nTus datos se conservan. Si el envío sí llegó, reintentar no lo '
          'duplica.';
    } else {
      mensaje = aviso.mensaje;
    }
    return Card(
      color: colores.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              claveReutilizada ? 'No se pudo registrar el envío' : aviso.titulo,
              key: const Key('titulo_error_envio'),
              style: TextStyle(fontWeight: FontWeight.bold, color: colores.onErrorContainer),
            ),
            const SizedBox(height: 4),
            Text(mensaje, style: TextStyle(color: colores.onErrorContainer)),
            if (claveReutilizada || puedeReintentar) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: claveReutilizada
                    ? OutlinedButton(
                        onPressed: alEmpezarNuevo,
                        child: const Text('Empezar envío nuevo'),
                      )
                    : OutlinedButton.icon(
                        onPressed: alReintentar,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvisoCatalogo extends StatelessWidget {
  const _AvisoCatalogo({required this.aviso, required this.alReintentar});

  final AvisoError aviso;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              aviso.titulo,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Sin el catálogo no se pueden elegir medio ni tipo de servicio. ${aviso.mensaje}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
