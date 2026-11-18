import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto3/services/api_client.dart';

http.Response _json(Object cuerpo, int codigo) => http.Response.bytes(
  utf8.encode(jsonEncode(cuerpo)),
  codigo,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('ApiClient.getJson', () {
    test('devuelve el JSON y usa la URL base mas la ruta', () async {
      late Uri pedida;
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        cliente: MockClient((request) async {
          pedida = request.url;
          return _json({'servicio': 'catalogo', 'ok': true}, 200);
        }),
      );

      final datos = await api.getJson('/api/catalogo/health/');

      expect(pedida.toString(), 'http://localhost:8080/api/catalogo/health/');
      expect(datos, {'servicio': 'catalogo', 'ok': true});
    });

    test('un 503 del gateway se convierte en mensaje con el detalle', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient(
          (_) async => _json({
            'error': 'servicio_no_disponible',
            'detalle': 'El servicio recomendar no respondió',
          }, 503),
        ),
      );

      await expectLater(
        api.getJson('/api/recomendar/health/'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.codigoHttp, 'codigoHttp', 503)
              .having((e) => e.codigoError, 'codigoError', 'servicio_no_disponible')
              .having((e) => e.mensaje, 'mensaje', 'El servicio recomendar no respondió'),
        ),
      );
    });

    test('un 503 sin cuerpo JSON usa un mensaje generico', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((_) async => http.Response('<html>503</html>', 503)),
      );

      await expectLater(
        api.getJson('/x/'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.codigoError, 'codigoError', 'servicio_no_disponible')
              .having((e) => e.mensaje, 'mensaje', contains('no está disponible')),
        ),
      );
    });

    test('otros errores HTTP usan el detalle del formato unico', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient(
          (_) async => _json({
            'error': 'ruta_no_encontrada',
            'detalle': 'La ruta solicitada no existe',
          }, 404),
        ),
      );

      await expectLater(
        api.getJson('/api/foo/'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.codigoHttp, 'codigoHttp', 404)
              .having((e) => e.codigoError, 'codigoError', 'ruta_no_encontrada'),
        ),
      );
    });

    test('un error de red se convierte en mensaje de conexion', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((_) async => throw http.ClientException('Connection refused')),
      );

      await expectLater(
        api.getJson('/x/'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.codigoHttp, 'codigoHttp', isNull)
              .having((e) => e.mensaje, 'mensaje', contains('No se pudo conectar')),
        ),
      );
    });

    test('se agota el tiempo limite', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        tiempoLimite: const Duration(milliseconds: 50),
        cliente: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return _json({'ok': true}, 200);
        }),
      );

      await expectLater(
        api.getJson('/x/'),
        throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje', contains('tardó'))),
      );
    });

    test('una respuesta 200 que no es JSON es un error claro', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((_) async => http.Response('hola', 200)),
      );

      await expectLater(
        api.getJson('/x/'),
        throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje', contains('formato'))),
      );
    });
  });
}
