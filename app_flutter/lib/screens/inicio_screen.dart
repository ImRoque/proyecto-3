import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'catalogo_screen.dart';
import 'estado_screen.dart';

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
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Estado',
          ),
        ],
      ),
    );
  }
}
