import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto3/screens/catalogo_screen.dart';
import 'package:proyecto3/services/api_client.dart';

Map<String, dynamic> _medio(String clave, String nombre, String descripcion) => {
  'clave': clave,
  'nombre': nombre,
  'descripcion': descripcion,
  'peso_max_kg': 20.0,
  'distancia_max_km': 40.0,
  'velocidad_kmh': 35.0,
  'costo_base': 40.0,
  'costo_por_km': 4.5,
};

final _catalogo = [
  _medio('camioneta', 'Camioneta', 'Paquetes grandes o pesados'),
  _medio('motocicleta', 'Motocicleta', 'Entregas rápidas en ciudad'),
];

http.Response _json(Object cuerpo, int codigo) => http.Response.bytes(
  utf8.encode(jsonEncode(cuerpo)),
  codigo,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Simula el catálogo: filtra por `q` en el nombre, como haría el servidor.
http.Response _responderCatalogo(http.Request request) {
  final q = request.url.queryParameters['q']?.toLowerCase();
  final medios = q == null
      ? _catalogo
      : _catalogo.where((m) => (m['nombre'] as String).toLowerCase().contains(q)).toList();
  return _json({'medios': medios, 'total': medios.length}, 200);
}

Future<void> _abrir(WidgetTester tester, http.Client cliente) {
  return tester.pumpWidget(
    MaterialApp(
      home: CatalogoScreen(
        api: ApiClient(baseUrl: 'http://gw', cliente: cliente),
      ),
    ),
  );
}

void main() {
  testWidgets('muestra cargando y despues la lista', (tester) async {
    final respuesta = Completer<http.Response>();
    await _abrir(tester, MockClient((_) => respuesta.future));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    respuesta.complete(_json({'medios': _catalogo, 'total': 2}, 200));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Camioneta'), findsOneWidget);
    expect(find.text('Motocicleta'), findsOneWidget);
  });

  testWidgets('buscar manda q y muestra solo los resultados', (tester) async {
    final pedidas = <Uri>[];
    await _abrir(
      tester,
      MockClient((request) async {
        pedidas.add(request.url);
        return _responderCatalogo(request);
      }),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'moto');
    await tester.pump(esperaBusqueda);
    await tester.pumpAndSettle();

    expect(pedidas.last.queryParameters, {'q': 'moto'});
    expect(find.text('Motocicleta'), findsOneWidget);
    expect(find.text('Camioneta'), findsNothing);
  });

  testWidgets('escribir rapido hace una sola busqueda', (tester) async {
    var llamadas = 0;
    await _abrir(
      tester,
      MockClient((request) async {
        llamadas++;
        return _responderCatalogo(request);
      }),
    );
    await tester.pumpAndSettle();
    expect(llamadas, 1);

    await tester.enterText(find.byType(TextField), 'm');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'mo');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'moto');
    await tester.pump(esperaBusqueda);
    await tester.pumpAndSettle();

    expect(llamadas, 2);
  });

  testWidgets('busqueda sin resultados muestra lista vacia', (tester) async {
    await _abrir(tester, MockClient((request) async => _responderCatalogo(request)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'submarino');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Sin resultados'), findsOneWidget);
    expect(find.text('No hay medios que coincidan con "submarino".'), findsOneWidget);
  });

  testWidgets('error muestra el mensaje y reintentar vuelve a consultar', (tester) async {
    var catalogoArriba = false;
    var llamadas = 0;
    await _abrir(
      tester,
      MockClient((request) async {
        llamadas++;
        if (!catalogoArriba) {
          return _json({
            'error': 'servicio_no_disponible',
            'detalle': 'El servicio catalogo no respondió',
          }, 503);
        }
        return _responderCatalogo(request);
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el catálogo'), findsOneWidget);
    expect(find.text('El servicio catalogo no respondió'), findsOneWidget);

    catalogoArriba = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(llamadas, 2);
    expect(find.text('No se pudo cargar el catálogo'), findsNothing);
    expect(find.text('Motocicleta'), findsOneWidget);
  });

  testWidgets('tocar un medio abre su detalle', (tester) async {
    await _abrir(
      tester,
      MockClient((request) async {
        if (request.url.path == '/api/catalogo/medios/motocicleta/') {
          return _json(_catalogo[1], 200);
        }
        return _responderCatalogo(request);
      }),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Motocicleta'));
    await tester.pumpAndSettle();

    expect(find.text('Peso máximo'), findsOneWidget);
    expect(find.text('20 kg'), findsOneWidget);
    expect(find.text('\$4.50 MXN'), findsOneWidget);
  });

  test('formatearNumero quita el .0 pero conserva decimales reales', () {
    expect(formatearNumero(20.0), '20');
    expect(formatearNumero(4.5), '4.5');
  });
}
