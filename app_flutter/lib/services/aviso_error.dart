import 'api_client.dart';

/// Cómo mostrar un [ApiException] en pantalla. Es el mismo texto en web y Android.
///
/// Cada pantalla indica qué [funcion] hace (por ejemplo "El catálogo") para que un `503` diga
/// qué no está disponible y deje claro que el resto de la app sigue funcionando.
class AvisoError {
  const AvisoError({required this.titulo, required this.mensaje, required this.reintentable});

  factory AvisoError.de(ApiException error, {required String funcion}) {
    return switch (error.tipo) {
      TipoError.sinConexion => const AvisoError(
        titulo: 'Sin conexión con el servidor',
        mensaje: 'No se pudo conectar. Revisa tu conexión a internet y vuelve a intentarlo.',
        reintentable: true,
      ),
      TipoError.tiempoAgotado => AvisoError(
        titulo: 'El servidor no respondió a tiempo',
        mensaje: '${error.mensaje} Vuelve a intentarlo.',
        reintentable: true,
      ),
      TipoError.noDisponible => AvisoError(
        titulo: '$funcion no está disponible',
        mensaje:
            '$funcion no está disponible por ahora. El resto de la app sigue funcionando; '
            'vuelve a intentarlo en unos minutos.',
        reintentable: true,
      ),
      TipoError.datosInvalidos => AvisoError(
        titulo: 'Revisa los datos',
        mensaje: error.mensaje,
        reintentable: false,
      ),
      TipoError.noEncontrado || TipoError.conflicto => AvisoError(
        titulo: 'No se pudo completar',
        mensaje: error.mensaje,
        reintentable: false,
      ),
      TipoError.otro => AvisoError(
        titulo: 'Ocurrió un error',
        mensaje: error.mensaje,
        reintentable: true,
      ),
    };
  }

  final String titulo;
  final String mensaje;

  /// `true` si conviene volver a intentar lo mismo; `false` si hay que corregir algo antes.
  final bool reintentable;
}
