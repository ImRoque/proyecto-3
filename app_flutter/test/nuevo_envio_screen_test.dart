import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto3/screens/nuevo_envio_screen.dart';
import 'package:proyecto3/services/api_client.dart';

import 'datos_pedidos.dart';

/// Gateway falso: responde el catálogo y deja que cada prueba decida el registro.
class _Gateway {
  _Gateway(this.registrar);

  /// Responde cada `POST /api/pedidos/`.
  Future<http.Response> Function(http.Request request) registrar;

  final registros = <http.Request>[];

  late final MockClient cliente = MockClient((request) async {
    switch (request.url.path) {
      case '/api/catalogo/medios/':
        return respuestaJson(mediosJson, 200);
      case '/api/catalogo/tipos-servicio/':
        return respuestaJson(tiposJson, 200);
      case '/api/pedidos/':
        registros.add(request);
        return registrar(request);
    }
    return respuestaJson({'error': 'ruta_no_encontrada'}, 404);
  });

  List<String?> get claves => [for (final r in registros) r.headers['Idempotency-Key']];
}

/// Genera claves predecibles: clave-1, clave-2, ...
String Function() _contadorClaves() {
  var n = 0;
  return () => 'clave-${++n}';
}

Future<void> _abrir(WidgetTester tester, _Gateway gateway) async {
  // Pantalla alta para que todo el formulario quepa sin desplazarse.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: NuevoEnvioScreen(
        api: ApiClient(baseUrl: 'http://gw', cliente: gateway.cliente),
        generarClave: _contadorClaves(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _elegir(WidgetTester tester, String campo, String opcion) async {
  await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, campo));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(opcion).last);
  await tester.pumpAndSettle();
}

Future<void> _llenar(WidgetTester tester, {String peso = '2.3'}) async {
  Future<void> escribir(String etiqueta, String texto) =>
      tester.enterText(find.widgetWithText(TextFormField, etiqueta), texto);
  await escribir('Origen', 'Av. Juárez 100');
  await escribir('Destino', 'Calle Hidalgo 25');
  await escribir('Distancia', '8.5');
  await escribir('Peso', peso);
  await escribir('Largo', '30');
  await escribir('Ancho', '20');
  await escribir('Alto', '15');

  await tester.tap(find.text('Sin elegir'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();

  await _elegir(tester, 'Medio de entrega', 'Motocicleta');
  await _elegir(tester, 'Tipo de servicio', 'Express');
}

final _confirmar = find.byKey(const Key('confirmar_envio'));

void main() {
  testWidgets('campos vacíos no mandan nada y muestran los errores', (tester) async {
    final gateway = _Gateway((_) async => respuestaJson(pedidoJson(), 201));
    await _abrir(tester, gateway);

    await tester.tap(_confirmar);
    await tester.pumpAndSettle();

    expect(gateway.registros, isEmpty);
    expect(find.text('Escribe el origen'), findsOneWidget);
    expect(find.text('Mayor que 0'), findsNWidgets(5));
    expect(find.text('Elige la fecha límite'), findsOneWidget);
    expect(find.text('Elige un medio de entrega'), findsOneWidget);
  });

  testWidgets('avisa si el peso supera la capacidad del medio elegido', (tester) async {
    final gateway = _Gateway((_) async => respuestaJson(pedidoJson(), 201));
    await _abrir(tester, gateway);
    await _llenar(tester);
    await _elegir(tester, 'Medio de entrega', 'Dron');

    await tester.tap(_confirmar);
    await tester.pumpAndSettle();

    expect(gateway.registros, isEmpty);
    expect(find.text('Dron: máx. 2 kg'), findsOneWidget);
  });

  testWidgets('elegir el medio no marca en rojo los campos que aún están vacíos', (tester) async {
    final gateway = _Gateway((_) async => respuestaJson(pedidoJson(), 201));
    await _abrir(tester, gateway);

    await _elegir(tester, 'Medio de entrega', 'Dron');

    expect(find.text('Elige un tipo de servicio'), findsNothing);
    expect(find.text('Mayor que 0'), findsNothing);

    // Con peso escrito sí avisa al cambiar de medio.
    await tester.enterText(find.widgetWithText(TextFormField, 'Peso'), '5');
    await _elegir(tester, 'Medio de entrega', 'Motocicleta');
    await _elegir(tester, 'Medio de entrega', 'Dron');
    expect(find.text('Dron: máx. 2 kg'), findsOneWidget);
  });

  testWidgets('manda el cuerpo del contrato con la Idempotency-Key', (tester) async {
    final gateway = _Gateway((_) async => respuestaJson(pedidoJson(), 201));
    await _abrir(tester, gateway);
    await _llenar(tester);

    await tester.tap(_confirmar);
    await tester.pumpAndSettle();

    final cuerpo = jsonDecode(utf8.decode(gateway.registros.single.bodyBytes));
    expect(gateway.claves, ['clave-1']);
    expect(cuerpo['origen'], 'Av. Juárez 100');
    expect(cuerpo['peso_kg'], 2.3);
    expect(cuerpo['dimensiones_cm'], {'largo': 30.0, 'ancho': 20.0, 'alto': 15.0});
    expect(cuerpo['medio'], 'motocicleta');
    expect(cuerpo['tipo_servicio'], 'express');
    expect(cuerpo['urgente'], false);
  });

  testWidgets('dos toques rápidos mandan una sola petición y muestran un folio', (tester) async {
    final respuesta = Completer<http.Response>();
    final gateway = _Gateway((_) => respuesta.future);
    await _abrir(tester, gateway);
    await _llenar(tester);

    // Dos toques en el mismo cuadro, antes de que el botón se redibuje.
    await tester.tap(_confirmar);
    await tester.tap(_confirmar);
    await tester.pump();

    expect(gateway.registros, hasLength(1));
    expect(tester.widget<FilledButton>(_confirmar).onPressed, isNull);
    expect(find.text('Registrando…'), findsOneWidget);

    // Un tercer toque con el botón ya deshabilitado tampoco hace nada.
    await tester.tap(_confirmar, warnIfMissed: false);
    await tester.pump();
    expect(gateway.registros, hasLength(1));

    respuesta.complete(respuestaJson(pedidoJson(), 201));
    await tester.pumpAndSettle();

    expect(find.text('PQ-20261117-C3JU'), findsOneWidget);
    expect(find.text('\$129.11 MXN'), findsOneWidget);
  });

  testWidgets('tras un error, Reintentar usa la misma clave', (tester) async {
    var intentos = 0;
    final gateway = _Gateway((_) async {
      intentos++;
      if (intentos == 1) {
        return respuestaJson({
          'error': 'servicio_no_disponible',
          'detalle': 'El servicio catalogo no respondió',
        }, 503);
      }
      return respuestaJson(pedidoJson(), 200);
    });
    await _abrir(tester, gateway);
    await _llenar(tester);

    await tester.tap(_confirmar);
    await tester.pumpAndSettle();

    expect(find.text('No se pudo registrar el envío'), findsOneWidget);
    expect(find.text('El servicio catalogo no respondió'), findsOneWidget);
    expect(tester.widget<FilledButton>(_confirmar).onPressed, isNotNull);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(gateway.claves, ['clave-1', 'clave-1']);
    expect(find.text('PQ-20261117-C3JU'), findsOneWidget);
  });

  testWidgets('después de un registro exitoso, el envío nuevo usa otra clave', (tester) async {
    var folios = ['PQ-20261117-AAAA', 'PQ-20261117-BBBB'];
    final gateway = _Gateway(
      (_) async => respuestaJson(pedidoJson(folio: folios.removeAt(0)), 201),
    );
    await _abrir(tester, gateway);

    await _llenar(tester);
    await tester.tap(_confirmar);
    await tester.pumpAndSettle();
    expect(find.text('PQ-20261117-AAAA'), findsOneWidget);

    await tester.tap(find.text('Nuevo envío').last);
    await tester.pumpAndSettle();

    // El formulario quedó limpio.
    expect(find.text('Av. Juárez 100'), findsNothing);
    expect(find.text('Sin elegir'), findsOneWidget);

    await _llenar(tester);
    await tester.tap(_confirmar);
    await tester.pumpAndSettle();

    expect(gateway.claves, ['clave-1', 'clave-2']);
    expect(find.text('PQ-20261117-BBBB'), findsOneWidget);
  });

  testWidgets('clave reutilizada con otros datos ofrece empezar un envío nuevo', (tester) async {
    final gateway = _Gateway((request) async {
      if (request.headers['Idempotency-Key'] == 'clave-1') {
        return respuestaJson({
          'error': 'idempotency_key_reutilizada',
          'detalle': 'La Idempotency-Key ya se usó con un cuerpo distinto',
        }, 409);
      }
      return respuestaJson(pedidoJson(), 201);
    });
    await _abrir(tester, gateway);
    await _llenar(tester);

    await tester.tap(_confirmar);
    await tester.pumpAndSettle();
    expect(find.textContaining('ya se registró con otros datos'), findsOneWidget);

    await tester.tap(find.text('Empezar envío nuevo'));
    await tester.pumpAndSettle();
    // Los datos se conservan; solo cambia la clave.
    expect(find.text('Av. Juárez 100'), findsOneWidget);

    await tester.tap(_confirmar);
    await tester.pumpAndSettle();

    expect(gateway.claves, ['clave-1', 'clave-2']);
    expect(find.text('PQ-20261117-C3JU'), findsOneWidget);
  });

  testWidgets('medio no apto según el servidor muestra el detalle sin Reintentar', (tester) async {
    final gateway = _Gateway(
      (_) async => respuestaJson({
        'error': 'medio_no_apto',
        'detalle': 'motocicleta lleva máximo 20 kg',
      }, 400),
    );
    await _abrir(tester, gateway);
    await _llenar(tester);

    await tester.tap(_confirmar);
    await tester.pumpAndSettle();

    expect(find.text('motocicleta lleva máximo 20 kg'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('si el catálogo falla, muestra error y Reintentar lo vuelve a cargar', (
    tester,
  ) async {
    var catalogoArriba = false;
    final cliente = MockClient((request) async {
      if (!catalogoArriba) {
        return respuestaJson({
          'error': 'servicio_no_disponible',
          'detalle': 'El servicio catalogo no respondió',
        }, 503);
      }
      return request.url.path == '/api/catalogo/medios/'
          ? respuestaJson(mediosJson, 200)
          : respuestaJson(tiposJson, 200);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: NuevoEnvioScreen(
          api: ApiClient(baseUrl: 'http://gw', cliente: cliente),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar los medios de entrega'), findsOneWidget);

    catalogoArriba = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar los medios de entrega'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Origen'), findsOneWidget);
  });
}
