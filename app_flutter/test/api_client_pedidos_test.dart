import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto3/models/pedido.dart';
import 'package:proyecto3/services/api_client.dart';

import 'datos_pedidos.dart';

final _solicitud = SolicitudPedido(
  origen: 'Av. Juárez 100',
  destino: 'Calle Hidalgo 25',
  distanciaKm: 8.5,
  pesoKg: 2.3,
  dimensiones: const Dimensiones(largo: 30, ancho: 20, alto: 15),
  urgente: false,
  seguro: true,
  fechaLimite: DateTime(2026, 11, 20),
  medio: 'motocicleta',
  tipoServicio: 'express',
);

void main() {
  group('ApiClient.registrarPedido', () {
    test('manda POST con Idempotency-Key y el cuerpo del contrato', () async {
      late http.Request pedida;
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((request) async {
          pedida = request;
          return respuestaJson(pedidoJson(), 201);
        }),
      );

      final pedido = await api.registrarPedido(_solicitud, idempotencyKey: 'clave-1');

      expect(pedida.method, 'POST');
      expect(pedida.url.toString(), 'http://gw/api/pedidos/');
      expect(pedida.headers['Idempotency-Key'], 'clave-1');
      expect(pedida.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(utf8.decode(pedida.bodyBytes)), _solicitud.toJson());
      expect(pedido.folio, 'PQ-20261117-C3JU');
    });

    test('un 200 por clave repetida devuelve el mismo pedido', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((_) async => respuestaJson(pedidoJson(), 200)),
      );

      final pedido = await api.registrarPedido(_solicitud, idempotencyKey: 'clave-1');

      expect(pedido.folio, 'PQ-20261117-C3JU');
    });

    for (final (codigo, error) in [
      (400, 'datos_invalidos'),
      (400, 'medio_no_apto'),
      (409, 'idempotency_key_reutilizada'),
      (503, 'servicio_no_disponible'),
    ]) {
      test('$codigo $error llega como ApiException con el detalle', () async {
        final api = ApiClient(
          baseUrl: 'http://gw',
          cliente: MockClient(
            (_) async => respuestaJson({'error': error, 'detalle': 'Detalle $error'}, codigo),
          ),
        );

        await expectLater(
          api.registrarPedido(_solicitud, idempotencyKey: 'clave-1'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.codigoHttp, 'codigoHttp', codigo)
                .having((e) => e.codigoError, 'codigoError', error)
                .having((e) => e.mensaje, 'mensaje', 'Detalle $error'),
          ),
        );
      });
    }

    test('sin conexión lanza ApiException sin código HTTP', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((_) async => throw http.ClientException('sin red')),
      );

      await expectLater(
        api.registrarPedido(_solicitud, idempotencyKey: 'clave-1'),
        throwsA(isA<ApiException>().having((e) => e.codigoHttp, 'codigoHttp', isNull)),
      );
    });
  });

  group('ApiClient.consultarPedido', () {
    test('consulta por folio y lee los datos mínimos', () async {
      late Uri pedida;
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient((request) async {
          pedida = request.url;
          return respuestaJson(resumenJson(estado: 'EN_CAMINO'), 200);
        }),
      );

      final resumen = await api.consultarPedido('PQ-20261117-C3JU');

      expect(pedida.toString(), 'http://gw/api/pedidos/PQ-20261117-C3JU/');
      expect(resumen.estado, 'EN_CAMINO');
    });

    test('folio inexistente lanza ApiException 404', () async {
      final api = ApiClient(
        baseUrl: 'http://gw',
        cliente: MockClient(
          (_) async => respuestaJson({'error': 'no_encontrado', 'detalle': 'No existe'}, 404),
        ),
      );

      await expectLater(
        api.consultarPedido('PQ-20261117-7KQ3'),
        throwsA(isA<ApiException>().having((e) => e.codigoHttp, 'codigoHttp', 404)),
      );
    });
  });

  test('listarTiposServicio lee la lista del catálogo', () async {
    final api = ApiClient(
      baseUrl: 'http://gw',
      cliente: MockClient((_) async => respuestaJson(tiposJson, 200)),
    );

    final tipos = await api.listarTiposServicio();

    expect(tipos.map((t) => t.clave), ['estandar', 'express']);
    expect(tipos.last.multiplicadorCosto, 1.5);
  });
}
