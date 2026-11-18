import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto3/screens/inicio_screen.dart';
import 'package:proyecto3/services/api_client.dart';

void main() {
  testWidgets('la navegacion inferior cambia entre Catalogo y Estado', (tester) async {
    final cliente = MockClient((request) async {
      if (request.url.path == '/api/catalogo/medios/') {
        return http.Response(jsonEncode({'medios': [], 'total': 0}), 200);
      }
      final servicio = request.url.pathSegments[1];
      return http.Response(jsonEncode({'servicio': servicio, 'ok': true}), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: InicioScreen(
          api: ApiClient(baseUrl: 'http://gw', cliente: cliente),
          apiUrl: 'http://gw',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Arranca en Catálogo.
    expect(find.text('Buscar medio de entrega'), findsOneWidget);
    expect(find.text('Estado de los servicios'), findsNothing);

    await tester.tap(find.text('Estado'));
    await tester.pumpAndSettle();
    expect(find.text('Estado de los servicios'), findsOneWidget);
    expect(find.text('Conectado'), findsNWidgets(4));

    await tester.tap(find.text('Catálogo').last);
    await tester.pumpAndSettle();
    expect(find.text('Buscar medio de entrega'), findsOneWidget);
  });
}
