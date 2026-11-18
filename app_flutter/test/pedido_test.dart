import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto3/models/pedido.dart';
import 'package:proyecto3/services/idempotencia.dart';

import 'datos_pedidos.dart';

void main() {
  test('Pedido.fromJson lee la respuesta del contrato', () {
    final pedido = Pedido.fromJson(pedidoJson());

    expect(pedido.folio, 'PQ-20261117-C3JU');
    expect(pedido.dimensiones.largo, 30);
    expect(pedido.costo, 129.11);
    expect(pedido.fechaLimite, DateTime(2026, 11, 20));
    expect(pedido.fechaCreacion, DateTime.utc(2026, 11, 18, 4, 9, 12));
  });

  test('Pedido.fromJson acepta enteros donde hay números', () {
    final pedido = Pedido.fromJson({
      ...pedidoJson(),
      'distancia_km': 8,
      'dimensiones_cm': {'largo': 30, 'ancho': 20, 'alto': 15},
      'costo': 100,
    });

    expect(pedido.distanciaKm, 8.0);
    expect(pedido.costo, 100.0);
  });

  test('Pedido.fromJson lanza FormatException si falta un campo', () {
    expect(() => Pedido.fromJson(pedidoJson()..remove('folio')), throwsA(isA<FormatException>()));
  });

  test('PedidoResumen.fromJson lee la consulta por folio', () {
    final resumen = PedidoResumen.fromJson(resumenJson(estado: 'EN_CAMINO'));

    expect(resumen.estado, estadoEnCamino);
    expect(resumen.actualizadoEn, DateTime.utc(2026, 11, 18, 4, 9, 14));
  });

  test('SolicitudPedido.toJson produce el cuerpo del contrato', () {
    final solicitud = SolicitudPedido(
      origen: 'A',
      destino: 'B',
      distanciaKm: 8.5,
      pesoKg: 2.3,
      dimensiones: const Dimensiones(largo: 30, ancho: 20, alto: 15),
      urgente: false,
      seguro: true,
      fechaLimite: DateTime(2026, 1, 5),
      medio: 'motocicleta',
      tipoServicio: 'express',
    );

    expect(solicitud.toJson(), {
      'origen': 'A',
      'destino': 'B',
      'distancia_km': 8.5,
      'peso_kg': 2.3,
      'dimensiones_cm': {'largo': 30.0, 'ancho': 20.0, 'alto': 15.0},
      'urgente': false,
      'seguro': true,
      'fecha_limite': '2026-01-05',
      'medio': 'motocicleta',
      'tipo_servicio': 'express',
    });
  });

  test('normalizarFolio acepta minúsculas y rechaza formatos inválidos', () {
    expect(normalizarFolio(' pq-20261117-c3ju '), 'PQ-20261117-C3JU');
    expect(normalizarFolio('PQ-20261117-C3J'), isNull);
    expect(normalizarFolio('PQ-20261117-C3J0'), isNull); // 0 no está en el alfabeto
    expect(normalizarFolio('ABC-123'), isNull);
  });

  test('generarUuidV4 produce UUID v4 válidos y distintos', () {
    final formato = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final claves = {for (var i = 0; i < 200; i++) generarUuidV4()};

    expect(claves, hasLength(200));
    for (final clave in claves) {
      expect(clave, matches(formato));
    }
  });
}
