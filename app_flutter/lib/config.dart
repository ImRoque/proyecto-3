/// Configuración de la app que cambia según la plataforma.
///
/// La URL base del API Gateway se pasa al compilar o ejecutar:
///
/// ```
/// flutter run -d chrome --dart-define=API_URL=http://localhost:8080
/// flutter run -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8080
/// ```
///
/// Flutter solo conoce la URL del gateway, nunca las de los servicios internos.
library;

const String _apiUrlDefinida = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080',
);

/// URL base del gateway, sin `/` al final.
final String apiUrl = _apiUrlDefinida.endsWith('/')
    ? _apiUrlDefinida.substring(0, _apiUrlDefinida.length - 1)
    : _apiUrlDefinida;
