/// Tipo de servicio del catálogo (docs/api.md, sección "Catálogo").
class TipoServicio {
  const TipoServicio({
    required this.clave,
    required this.nombre,
    required this.descripcion,
    required this.tiempoMaxHoras,
    required this.multiplicadorCosto,
  });

  /// Crea el tipo a partir del JSON del contrato. Si no cumple, lanza [FormatException].
  factory TipoServicio.fromJson(Map<String, dynamic> json) {
    try {
      return TipoServicio(
        clave: json['clave'] as String,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String,
        tiempoMaxHoras: (json['tiempo_max_horas'] as num).toInt(),
        multiplicadorCosto: (json['multiplicador_costo'] as num).toDouble(),
      );
    } on TypeError {
      throw const FormatException('El tipo de servicio no tiene el formato del contrato.');
    }
  }

  /// Identificador fijo: `estandar`, `express` o `mismo_dia`.
  final String clave;
  final String nombre;
  final String descripcion;
  final int tiempoMaxHoras;
  final double multiplicadorCosto;
}
