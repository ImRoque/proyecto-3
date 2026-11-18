import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto3/screens/rastreo_screen.dart';
import 'package:proyecto3/services/api_client.dart';

import 'datos_pedidos.dart';

Future<void> _abrir(WidgetTester tester, http.Client cliente, {String? folioInicial}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RastreoScreen(
        api: ApiClient(baseUrl: 'http://gw', cliente: cliente),
        folioInicial: folioInicial,
      ),
    ),
  );
}

Future<void> _buscar(WidgetTester tester, String folio) async {
  await tester.enterText(find.byType(TextFormField), folio);
  await tester.testTextInput.receiveAction(TextInputAction.search);
}

/// Icono que se muestra en el paso [estado] de la línea de estados.
IconData? _iconoPaso(WidgetTester tester, String estado) => tester
    .widget<Icon>(find.descendant(of: find.byKey(Key('paso_$estado')), matching: find.byType(Icon)))
    .icon;

void main() {
  testWidgets('muestra cargando y después la línea de estados', (tester) async {
    final respuesta = Completer<http.Response>();
    late Uri pedida;
    await _abrir(
      tester,
      MockClient((request) {
        pedida = request.url;
        return respuesta.future;
      }),
    );

    await _buscar(tester, 'pq-20261117-c3ju');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(pedida.path, '/api/pedidos/PQ-20261117-C3JU/');

    respuesta.complete(respuestaJson(resumenJson(estado: 'EN_CAMINO'), 200));
    await tester.pumpAndSettle();

    expect(find.text('Creado'), findsOneWidget);
    expect(find.text('En camino'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
    expect(_iconoPaso(tester, 'CREADO'), Icons.check_circle);
    expect(_iconoPaso(tester, 'EN_CAMINO'), Icons.radio_button_checked);
    expect(_iconoPaso(tester, 'ENTREGADO'), Icons.radio_button_unchecked);
    expect(find.text('2026-11-20'), findsOneWidget);
  });

  testWidgets('un pedido cancelado muestra Creado y Cancelado', (tester) async {
    await _abrir(
      tester,
      MockClient((_) async => respuestaJson(resumenJson(estado: 'CANCELADO'), 200)),
      folioInicial: 'PQ-20261117-C3JU',
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.text('En camino'), findsNothing);
    expect(_iconoPaso(tester, 'CANCELADO'), Icons.cancel);
  });

  testWidgets('folio inexistente muestra Folio no encontrado', (tester) async {
    await _abrir(
      tester,
      MockClient(
        (_) async => respuestaJson({
          'error': 'no_encontrado',
          'detalle': 'No existe el pedido con folio PQ-20261117-7KQ3',
        }, 404),
      ),
    );

    await _buscar(tester, 'PQ-20261117-7KQ3');
    await tester.pumpAndSettle();

    expect(find.text('Folio no encontrado'), findsOneWidget);
    expect(find.textContaining('PQ-20261117-7KQ3'), findsWidgets);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('folio con formato inválido no consulta al servidor', (tester) async {
    var llamadas = 0;
    await _abrir(
      tester,
      MockClient((_) async {
        llamadas++;
        return respuestaJson(resumenJson(), 200);
      }),
    );

    await _buscar(tester, 'ABC-123');
    await tester.pumpAndSettle();

    expect(llamadas, 0);
    expect(find.text('El folio tiene el formato PQ-AAAAMMDD-XXXX'), findsOneWidget);
  });

  testWidgets('error del servidor muestra el mensaje y Reintentar vuelve a consultar', (
    tester,
  ) async {
    var pedidosArriba = false;
    var llamadas = 0;
    await _abrir(
      tester,
      MockClient((_) async {
        llamadas++;
        if (!pedidosArriba) {
          return respuestaJson({
            'error': 'servicio_no_disponible',
            'detalle': 'El servicio pedidos no respondió',
          }, 503);
        }
        return respuestaJson(resumenJson(estado: 'ENTREGADO'), 200);
      }),
    );

    await _buscar(tester, 'PQ-20261117-C3JU');
    await tester.pumpAndSettle();
    expect(find.text('No se pudo consultar el pedido'), findsOneWidget);
    expect(find.text('El servicio pedidos no respondió'), findsOneWidget);

    pedidosArriba = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(llamadas, 2);
    expect(_iconoPaso(tester, 'ENTREGADO'), Icons.radio_button_checked);
  });
}
