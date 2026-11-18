/// Medio de entrega del catálogo (docs/api.md, sección "Catálogo").
class MedioEntrega {
  const MedioEntrega({
    required this.clave,
    required this.nombre,
    required this.descripcion,
    required this.pesoMaxKg,
    required this.distanciaMaxKm,
    required this.velocidadKmh,
    required this.costoBase,
    required this.costoPorKm,
  });

  /// Crea el medio a partir del JSON del contrato.
  ///
  /// Los campos numéricos se leen como `num` porque el servidor puede mandar `20` o `20.0`.
  /// Si falta un campo o tiene otro tipo, lanza [FormatException].
  factory MedioEntrega.fromJson(Map<String, dynamic> json) {
    try {
      return MedioEntrega(
        clave: json['clave'] as String,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String,
        pesoMaxKg: (json['peso_max_kg'] as num).toDouble(),
        distanciaMaxKm: (json['distancia_max_km'] as num).toDouble(),
        velocidadKmh: (json['velocidad_kmh'] as num).toDouble(),
        costoBase: (json['costo_base'] as num).toDouble(),
        costoPorKm: (json['costo_por_km'] as num).toDouble(),
      );
    } on TypeError {
      throw const FormatException('El medio de entrega no tiene el formato del contrato.');
    }
  }

  /// Identificador fijo: `camioneta`, `motocicleta`, `bicicleta` o `dron`.
  final String clave;
  final String nombre;
  final String descripcion;
  final double pesoMaxKg;
  final double distanciaMaxKm;
  final double velocidadKmh;

  /// Costo fijo por envío, en MXN.
  final double costoBase;

  /// Costo por kilómetro, en MXN.
  final double costoPorKm;
}
