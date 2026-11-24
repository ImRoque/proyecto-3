/// Respuesta de `POST /api/asistente/` (docs/api.md, "Conversar con el asistente").
class RespuestaAsistente {
  const RespuestaAsistente({required this.intencion, required this.respuesta});

  /// `rastrear`, `cotizar`, `recomendar`, `horarios`, `saludo` o `desconocida`.
  final String intencion;

  /// Texto para mostrar al comprador.
  final String respuesta;

  factory RespuestaAsistente.fromJson(Map<String, dynamic> json) {
    final intencion = json['intencion'];
    final respuesta = json['respuesta'];
    if (intencion is! String || respuesta is! String) {
      throw const FormatException('Faltan intencion o respuesta');
    }
    return RespuestaAsistente(intencion: intencion, respuesta: respuesta);
  }
}

/// Un mensaje de la conversación, del usuario o del asistente.
class MensajeChat {
  const MensajeChat.usuario(this.texto) : deUsuario = true, intencion = null;

  const MensajeChat.asistente(this.texto, {this.intencion}) : deUsuario = false;

  final String texto;
  final bool deUsuario;

  /// Intención que detectó el asistente (solo en sus mensajes).
  final String? intencion;
}
