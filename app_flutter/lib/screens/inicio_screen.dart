import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'catalogo_screen.dart';
import 'chat_screen.dart';
import 'estado_screen.dart';
import 'nuevo_envio_screen.dart';
import 'rastreo_screen.dart';

/// Pantalla principal con navegación inferior entre las secciones de la app.
///
/// Usa [IndexedStack] para que cada pestaña conserve su estado (por ejemplo, la
/// búsqueda del catálogo) al cambiar de una a otra.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key, required this.api, required this.apiUrl});

  final ApiClient api;

  /// URL base del gateway, para la pantalla de estado.
  final String apiUrl;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pestana,
        children: [
          CatalogoScreen(api: widget.api),
          NuevoEnvioScreen(api: widget.api),
          RastreoScreen(api: widget.api),
          ChatScreen(api: widget.api),
          EstadoScreen(api: widget.api, apiUrl: widget.apiUrl),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Enviar',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore),
            label: 'Rastrear',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Asistente',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Estado',
          ),
        ],
      ),
    );
  }
}
