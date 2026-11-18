import 'package:flutter/material.dart';

import 'config.dart';
import 'screens/inicio_screen.dart';
import 'services/api_client.dart';

void main() {
  runApp(ProyectoApp(api: ApiClient(baseUrl: apiUrl)));
}

class ProyectoApp extends StatelessWidget {
  const ProyectoApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paquetería',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: InicioScreen(api: api, apiUrl: apiUrl),
    );
  }
}
