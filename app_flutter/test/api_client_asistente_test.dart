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
  group('ApiClient.enviarMensaje', () {
    test('manda POST con el mensaje en UTF-8 y lee intencion y respuesta', () async {
      late http.Request pedida;
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((request) async {
          pedida = request;
          return _json({'intencion': 'horarios', 'respuesta': 'Atendemos de lunes a sábado.'}, 200);
        }),
      );

      final respuesta = await api.enviarMensaje('¿qué horarios tienen?');

      expect(pedida.method, 'POST');
      expect(pedida.url.toString(), 'http://gw/api/asistente/');
      expect(pedida.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(utf8.decode(pedida.bodyBytes)), {'mensaje': '¿qué horarios tienen?'});
      expect(respuesta.intencion, 'horarios');
      expect(respuesta.respuesta, 'Atendemos de lunes a sábado.');
    });

    for (final (codigo, error) in [
      (400, 'mensaje_vacio'),
      (400, 'datos_invalidos'),
      (503, 'modelo_no_disponible'),
      (503, 'servicio_no_disponible'),
    ]) {
      test('$codigo $error llega como ApiException con el detalle', () async {
        final api = ApiClient(
          baseUrl: 'http://gw',
          cliente: MockClient(
            (_) async => _json({'error': error, 'detalle': 'Detalle $error'}, codigo),
          ),
        );

        await expectLater(
          api.enviarMensaje('hola'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.codigoHttp, 'codigoHttp', codigo)
                .having((e) => e.codigoError, 'codigoError', error)
                .having((e) => e.mensaje, 'mensaje', 'Detalle $error'),
          ),
        );
      });
    }

    test('una respuesta sin intencion es un formato inesperado', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((_) async => _json({'respuesta': 'hola'}, 200)),
      );

      await expectLater(
        api.enviarMensaje('hola'),
        throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje', contains('formato'))),
      );
    });

    test('sin conexión da un mensaje claro', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((_) async => throw http.ClientException('sin red')),
      );

      await expectLater(
        api.enviarMensaje('hola'),
        throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje', contains('conectar'))),
      );
    });
  });
}
