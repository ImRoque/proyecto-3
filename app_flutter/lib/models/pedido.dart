/// Modelos del pedido (docs/api.md, sección "Pedidos").
library;

/// Estados del pedido, en el orden normal de avance.
const String estadoCreado = 'CREADO';
const String estadoEnCamino = 'EN_CAMINO';
const String estadoEntregado = 'ENTREGADO';
const String estadoCancelado = 'CANCELADO';

/// Camino normal de un pedido; `CANCELADO` solo puede salir de `CREADO`.
const List<String> lineaEstados = [estadoCreado, estadoEnCamino, estadoEntregado];

/// Formato del folio: `PQ-AAAAMMDD-XXXX` con `A-Z` y `2-9`, sin `O`, `I`, `0` ni `1`.
final RegExp formatoFolio = RegExp(r'^PQ-\d{8}-[A-HJ-NP-Z2-9]{4}$');

/// Devuelve el folio en mayúsculas y sin espacios, o `null` si no tiene el formato.
String? normalizarFolio(String texto) {
  final folio = texto.trim().toUpperCase();
  return formatoFolio.hasMatch(folio) ? folio : null;
}

/// Medidas del paquete en centímetros.
class Dimensiones {
  const Dimensiones({required this.largo, required this.ancho, required this.alto});

  factory Dimensiones.fromJson(Map<String, dynamic> json) => Dimensiones(
    largo: (json['largo'] as num).toDouble(),
    ancho: (json['ancho'] as num).toDouble(),
    alto: (json['alto'] as num).toDouble(),
  );

  final double largo;
  final double ancho;
  final double alto;

  Map<String, dynamic> toJson() => {'largo': largo, 'ancho': ancho, 'alto': alto};
}

/// Cuerpo de `POST /api/pedidos/`.
class SolicitudPedido {
  const SolicitudPedido({
    required this.origen,
    required this.destino,
    required this.distanciaKm,
    required this.pesoKg,
    required this.dimensiones,
    required this.urgente,
    required this.seguro,
    required this.fechaLimite,
    required this.medio,
    required this.tipoServicio,
  });

  final String origen;
  final String destino;
  final double distanciaKm;
  final double pesoKg;
  final Dimensiones dimensiones;
  final bool urgente;
  final bool seguro;

  /// Solo se usa la fecha (año, mes y día).
  final DateTime fechaLimite;
  final String medio;
  final String tipoServicio;

  Map<String, dynamic> toJson() => {
    'origen': origen,
    'destino': destino,
    'distancia_km': distanciaKm,
    'peso_kg': pesoKg,
    'dimensiones_cm': dimensiones.toJson(),
    'urgente': urgente,
    'seguro': seguro,
    'fecha_limite': formatearFecha(fechaLimite),
    'medio': medio,
    'tipo_servicio': tipoServicio,
  };
}

/// Respuesta de registrar un pedido (datos completos).
class Pedido {
  const Pedido({
    required this.folio,
    required this.estado,
    required this.origen,
    required this.destino,
    required this.distanciaKm,
    required this.pesoKg,
    required this.dimensiones,
    required this.urgente,
    required this.seguro,
    required this.fechaLimite,
    required this.medio,
    required this.tipoServicio,
    required this.costo,
    required this.moneda,
    required this.fechaCreacion,
  });

  /// Crea el pedido a partir del JSON del contrato. Si no cumple, lanza [FormatException].
  ///
  /// Los números se leen como `num` porque el servidor puede mandar `30` o `30.0`.
  factory Pedido.fromJson(Map<String, dynamic> json) {
    try {
      return Pedido(
        folio: json['folio'] as String,
        estado: json['estado'] as String,
        origen: json['origen'] as String,
        destino: json['destino'] as String,
        distanciaKm: (json['distancia_km'] as num).toDouble(),
        pesoKg: (json['peso_kg'] as num).toDouble(),
        dimensiones: Dimensiones.fromJson(json['dimensiones_cm'] as Map<String, dynamic>),
        urgente: json['urgente'] as bool,
        seguro: json['seguro'] as bool,
        fechaLimite: DateTime.parse(json['fecha_limite'] as String),
        medio: json['medio'] as String,
        tipoServicio: json['tipo_servicio'] as String,
        costo: (json['costo'] as num).toDouble(),
        moneda: json['moneda'] as String,
        fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      );
    } on TypeError {
      throw const FormatException('El pedido no tiene el formato del contrato.');
    }
  }

  final String folio;
  final String estado;
  final String origen;
  final String destino;
  final double distanciaKm;
  final double pesoKg;
  final Dimensiones dimensiones;
  final bool urgente;
  final bool seguro;
  final DateTime fechaLimite;
  final String medio;
  final String tipoServicio;
  final double costo;
  final String moneda;
  final DateTime fechaCreacion;
}

/// Respuesta de `GET /api/pedidos/<folio>/`: solo datos mínimos para rastrear.
class PedidoResumen {
  const PedidoResumen({
    required this.folio,
    required this.estado,
    required this.medio,
    required this.tipoServicio,
    required this.fechaCreacion,
    required this.fechaLimite,
    required this.actualizadoEn,
  });

  factory PedidoResumen.fromJson(Map<String, dynamic> json) {
    try {
      return PedidoResumen(
        folio: json['folio'] as String,
        estado: json['estado'] as String,
        medio: json['medio'] as String,
        tipoServicio: json['tipo_servicio'] as String,
        fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
        fechaLimite: DateTime.parse(json['fecha_limite'] as String),
        actualizadoEn: DateTime.parse(json['actualizado_en'] as String),
      );
    } on TypeError {
      throw const FormatException('El pedido no tiene el formato del contrato.');
    }
  }

  final String folio;
  final String estado;
  final String medio;
  final String tipoServicio;
  final DateTime fechaCreacion;
  final DateTime fechaLimite;
  final DateTime actualizadoEn;
}

String _dosDigitos(int n) => n.toString().padLeft(2, '0');

/// `AAAA-MM-DD`, el formato de fecha del contrato.
String formatearFecha(DateTime fecha) =>
    '${fecha.year}-${_dosDigitos(fecha.month)}-${_dosDigitos(fecha.day)}';

/// `AAAA-MM-DD HH:MM` en la hora local del dispositivo, para mostrar.
String formatearFechaHora(DateTime fecha) {
  final local = fecha.toLocal();
  return '${formatearFecha(local)} ${_dosDigitos(local.hour)}:${_dosDigitos(local.minute)}';
}
