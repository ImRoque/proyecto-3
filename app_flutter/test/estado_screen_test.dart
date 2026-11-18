import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto3/screens/estado_screen.dart';
import 'package:proyecto3/services/api_client.dart';

void main() {
  testWidgets('muestra conectados y no disponibles, y reintentar vuelve a consultar', (
    tester,
  ) async {
    var recomendarArriba = false;
    var llamadas = 0;

    final cliente = MockClient((request) async {
      llamadas++;
      final servicio = request.url.pathSegments[1];
      if (servicio == 'recomendar' && !recomendarArriba) {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': 'servicio_no_disponible',
              'detalle': 'El servicio recomendar no respondió',
            }),
          ),
          503,
        );
      }
      return http.Response(jsonEncode({'servicio': servicio, 'ok': true}), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: EstadoScreen(
          api: ApiClient(baseUrl: 'http://gw', cliente: cliente),
          apiUrl: 'http://gw',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(llamadas, 4);
    expect(find.text('Conectado'), findsNWidgets(3));
    expect(find.text('No disponible: El servicio recomendar no respondió'), findsOneWidget);
    expect(find.text('Gateway: http://gw'), findsOneWidget);

    recomendarArriba = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(llamadas, 8);
    expect(find.text('Conectado'), findsNWidgets(4));
    expect(find.textContaining('No disponible'), findsNothing);
  });
}
