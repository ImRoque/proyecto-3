import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto3/screens/chat_screen.dart';
import 'package:proyecto3/services/api_client.dart';

http.Response _json(Object cuerpo, int codigo) => http.Response.bytes(
  utf8.encode(jsonEncode(cuerpo)),
  codigo,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _abrir(WidgetTester tester, http.Client cliente) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChatScreen(
        api: ApiClient(baseUrl: 'http://gw', cliente: cliente),
      ),
    ),
  );
}

Future<void> _escribir(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(const Key('campo_mensaje')), texto);
  await tester.pump();
}

Finder get _botonEnviar => find.widgetWithIcon(IconButton, Icons.send);

bool _habilitado(WidgetTester tester) => tester.widget<IconButton>(_botonEnviar).onPressed != null;

void main() {
  testWidgets('muestra la burbuja del usuario, "escribiendo" y la del asistente', (tester) async {
    final respuesta = Completer<http.Response>();
    final pedidos = <String>[];
    await _abrir(
      tester,
      MockClient((request) {
        pedidos.add(jsonDecode(utf8.decode(request.bodyBytes))['mensaje'] as String);
        return respuesta.future;
      }),
    );
    expect(find.text('¿En qué te ayudo?'), findsOneWidget);

    await _escribir(tester, '  ¿qué horarios tienen?  ');
    await tester.tap(_botonEnviar);
    await tester.pump();

    expect(pedidos, ['¿qué horarios tienen?']);
    expect(find.byKey(const Key('burbuja_usuario')), findsOneWidget);
    expect(find.text('¿qué horarios tienen?'), findsOneWidget);
    expect(find.byKey(const Key('escribiendo')), findsOneWidget);
    expect(find.text('Escribiendo…'), findsOneWidget);
    // El campo se limpia y no se puede enviar otro mientras espera.
    expect(tester.widget<TextField>(find.byKey(const Key('campo_mensaje'))).controller!.text, '');
    await _escribir(tester, 'otro');
    expect(_habilitado(tester), isFalse);

    respuesta.complete(_json({'intencion': 'horarios', 'respuesta': 'Atendemos de 8 a 20.'}, 200));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('escribiendo')), findsNothing);
    expect(find.byKey(const Key('burbuja_asistente')), findsOneWidget);
    expect(find.text('Atendemos de 8 a 20.'), findsOneWidget);
    expect(_habilitado(tester), isTrue);
  });

  testWidgets('enviar con la tecla del teclado también funciona', (tester) async {
    await _abrir(
      tester,
      MockClient((_) async => _json({'intencion': 'saludo', 'respuesta': '¡Hola!'}, 200)),
    );

    await _escribir(tester, 'hola');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('¡Hola!'), findsOneWidget);
    // El campo conserva el foco para escribir el siguiente mensaje.
    final campo = tester.widget<TextField>(find.byKey(const Key('campo_mensaje')));
    expect(campo.focusNode!.hasFocus, isTrue);
  });

  testWidgets('no se puede enviar un mensaje vacío', (tester) async {
    var llamadas = 0;
    await _abrir(
      tester,
      MockClient((_) async {
        llamadas++;
        return _json({'intencion': 'saludo', 'respuesta': 'hola'}, 200);
      }),
    );

    expect(_habilitado(tester), isFalse);
    await _escribir(tester, '    ');
    expect(_habilitado(tester), isFalse);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(llamadas, 0);
    expect(find.byKey(const Key('burbuja_usuario')), findsNothing);
  });

  testWidgets('si falla muestra el error y reintentar reenvía el mismo mensaje', (tester) async {
    final pedidos = <String>[];
    var falla = true;
    await _abrir(
      tester,
      MockClient((request) async {
        pedidos.add(jsonDecode(utf8.decode(request.bodyBytes))['mensaje'] as String);
        if (falla) {
          return _json({
            'error': 'servicio_no_disponible',
            'detalle': 'El servicio asistente no respondió',
          }, 503);
        }
        return _json({'intencion': 'saludo', 'respuesta': '¡Hola! ¿En qué te ayudo?'}, 200);
      }),
    );

    await _escribir(tester, 'hola');
    await tester.tap(_botonEnviar);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aviso_error')), findsOneWidget);
    expect(find.textContaining('El asistente no está disponible'), findsOneWidget);
    expect(find.textContaining('El resto de la app sigue funcionando'), findsOneWidget);
    expect(find.byKey(const Key('escribiendo')), findsNothing);
    expect(find.byKey(const Key('burbuja_usuario')), findsOneWidget);

    falla = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(pedidos, ['hola', 'hola']);
    expect(find.byKey(const Key('aviso_error')), findsNothing);
    // El mensaje del usuario no se duplica al reintentar.
    expect(find.byKey(const Key('burbuja_usuario')), findsOneWidget);
    expect(find.text('¡Hola! ¿En qué te ayudo?'), findsOneWidget);
  });

  testWidgets('sin conexión muestra un mensaje claro y Reintentar', (tester) async {
    await _abrir(tester, MockClient((_) async => throw http.ClientException('sin red')));

    await _escribir(tester, 'hola');
    await tester.tap(_botonEnviar);
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin conexión con el servidor'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('un 400 devuelve el mensaje al campo para corregirlo, sin Reintentar', (
    tester,
  ) async {
    await _abrir(
      tester,
      MockClient(
        (_) async => _json({
          'error': 'datos_invalidos',
          'detalle': 'El mensaje no puede tener más de 500 caracteres',
        }, 400),
      ),
    );

    await _escribir(tester, 'hola');
    await tester.tap(_botonEnviar);
    await tester.pumpAndSettle();

    expect(find.textContaining('Revisa los datos'), findsOneWidget);
    expect(find.textContaining('no puede tener más de 500 caracteres'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    final campo = tester.widget<TextField>(find.byKey(const Key('campo_mensaje')));
    expect(campo.controller!.text, 'hola');
  });

  testWidgets('el campo no deja escribir más de 500 caracteres', (tester) async {
    await _abrir(tester, MockClient((_) async => _json({}, 200)));

    await _escribir(tester, 'a' * 600);

    final campo = tester.widget<TextField>(find.byKey(const Key('campo_mensaje')));
    expect(campo.controller!.text.length, largoMaximoMensaje);
  });
}
