import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto3/services/api_client.dart';
import 'package:proyecto3/services/aviso_error.dart';

import 'datos_pedidos.dart';

/// Llama a una ruta cualquiera con un cliente falso y devuelve el error que lanza.
Future<ApiException> _errorDe(
  MockClientHandler responder, {
  Duration tiempoLimite = const Duration(seconds: 5),
}) async {
  final api = ApiClient(
    baseUrl: 'http://gw',
    cliente: MockClient(responder),
    tiempoLimite: tiempoLimite,
  );
  try {
    await api.getJson('/api/catalogo/medios/');
  } on ApiException catch (e) {
    return e;
  }
  fail('Se esperaba ApiException');
}

void main() {
  group('ApiClient clasifica cada fallo', () {
    test('ClientException (web y Android) es sin conexión', () async {
      final error = await _errorDe((_) async => throw http.ClientException('XMLHttpRequest'));
      expect(error.tipo, TipoError.sinConexion);
      expect(error.codigoHttp, isNull);
    });

    test('otra excepción de red también es sin conexión', () async {
      final error = await _errorDe((_) async => throw const _FalloSocket());
      expect(error.tipo, TipoError.sinConexion);
    });

    test('sin respuesta dentro del tiempo límite es tiempo agotado', () async {
      final reloj = Stopwatch()..start();
      final error = await _errorDe((_) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        return respuestaJson({}, 200);
      }, tiempoLimite: const Duration(milliseconds: 200));
      expect(error.tipo, TipoError.tiempoAgotado);
      expect(reloj.elapsed, lessThan(const Duration(seconds: 1)));
    });

    final porCodigo = {
      400: TipoError.datosInvalidos,
      404: TipoError.noEncontrado,
      409: TipoError.conflicto,
      503: TipoError.noDisponible,
      500: TipoError.otro,
    };
    porCodigo.forEach((codigo, tipo) {
      test('HTTP $codigo es $tipo', () async {
        final error = await _errorDe(
          (_) async => respuestaJson({'error': 'x', 'detalle': 'detalle $codigo'}, codigo),
        );
        expect(error.tipo, tipo);
        expect(error.mensaje, 'detalle $codigo');
      });
    });

    test('el tiempo límite por defecto es mayor que el peor caso del servidor', () {
      expect(ApiClient(baseUrl: 'http://gw').tiempoLimite, tiempoLimitePorDefecto);
      expect(tiempoLimitePorDefecto, greaterThan(const Duration(seconds: 6)));
      expect(tiempoLimitePorDefecto, lessThan(const Duration(seconds: 10)));
    });
  });

  group('AvisoError', () {
    AvisoError aviso(ApiException e) => AvisoError.de(e, funcion: 'El catálogo');

    test('503 dice qué función falla y que lo demás sigue funcionando', () {
      final a = aviso(const ApiException('El servicio catalogo no respondió', codigoHttp: 503));
      expect(a.titulo, 'El catálogo no está disponible');
      expect(a.mensaje, contains('El resto de la app sigue funcionando'));
      expect(a.reintentable, isTrue);
    });

    test('400 muestra el detalle del servidor y no se reintenta', () {
      final a = aviso(const ApiException('El peso debe ser mayor que 0', codigoHttp: 400));
      expect(a.titulo, 'Revisa los datos');
      expect(a.mensaje, 'El peso debe ser mayor que 0');
      expect(a.reintentable, isFalse);
    });

    test('sin conexión y tiempo agotado se reintentan', () {
      final sinRed = aviso(const ApiException('x', tipo: TipoError.sinConexion));
      final lento = aviso(const ApiException('Tardó 8 s.', tipo: TipoError.tiempoAgotado));
      expect(sinRed.titulo, 'Sin conexión con el servidor');
      expect(lento.titulo, 'El servidor no respondió a tiempo');
      expect(lento.mensaje, startsWith('Tardó 8 s.'));
      expect([sinRed.reintentable, lento.reintentable], [isTrue, isTrue]);
    });

    test('404 y 409 no se reintentan', () {
      expect(aviso(const ApiException('x', codigoHttp: 404)).reintentable, isFalse);
      expect(aviso(const ApiException('x', codigoHttp: 409)).reintentable, isFalse);
    });
  });
}

/// Simula un error de socket que no es `ClientException` (p. ej. `SocketException` en Android).
class _FalloSocket implements Exception {
  const _FalloSocket();
}
