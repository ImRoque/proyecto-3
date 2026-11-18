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

  group('ApiClient catalogo', () {
    const moto = {
      'clave': 'motocicleta',
      'nombre': 'Motocicleta',
      'descripcion': 'Entregas rápidas en ciudad',
      'peso_max_kg': 20.0,
      'distancia_max_km': 40.0,
      'velocidad_kmh': 35.0,
      'costo_base': 40.0,
      'costo_por_km': 4.5,
    };

    test('listarMedios sin busqueda no manda q', () async {
      late Uri pedida;
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((request) async {
          pedida = request.url;
          return _json({
            'medios': [moto],
            'total': 1,
          }, 200);
        }),
      );

      final medios = await api.listarMedios(q: '   ');

      expect(pedida.toString(), 'http://gw/api/catalogo/medios/');
      expect(medios.single.clave, 'motocicleta');
      expect(medios.single.costoPorKm, 4.5);
    });

    test('listarMedios manda q recortado y codificado', () async {
      late Uri pedida;
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((request) async {
          pedida = request.url;
          return _json({'medios': [], 'total': 0}, 200);
        }),
      );

      final medios = await api.listarMedios(q: ' rápidas ');

      expect(pedida.path, '/api/catalogo/medios/');
      expect(pedida.queryParameters, {'q': 'rápidas'});
      expect(pedida.query, 'q=r%C3%A1pidas');
      expect(medios, isEmpty);
    });

    test('listarMedios con formato inesperado lanza ApiException', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient(
          (_) async => _json({
            'medios': [
              {'clave': 'x'},
            ],
          }, 200),
        ),
      );

      await expectLater(
        api.listarMedios(),
        throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje', contains('formato'))),
      );
    });

    test('obtenerMedio pide la ruta de detalle', () async {
      late Uri pedida;
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((request) async {
          pedida = request.url;
          return _json(moto, 200);
        }),
      );

      final medio = await api.obtenerMedio('motocicleta');

      expect(pedida.toString(), 'http://gw/api/catalogo/medios/motocicleta/');
      expect(medio.nombre, 'Motocicleta');
    });

    test('obtenerMedio inexistente lanza no_encontrado', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient(
          (_) async => _json({
            'error': 'no_encontrado',
            'detalle': 'No existe el medio con clave submarino',
          }, 404),
        ),
      );

      await expectLater(
        api.obtenerMedio('submarino'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.codigoHttp, 'codigoHttp', 404)
              .having((e) => e.codigoError, 'codigoError', 'no_encontrado')
              .having((e) => e.mensaje, 'mensaje', 'No existe el medio con clave submarino'),
        ),
      );
    });
  });
}
