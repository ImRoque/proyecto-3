import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Servicios cuyo estado se consulta, en el orden en que se muestran.
const List<String> serviciosMonitoreados = ['catalogo', 'pedidos', 'recomendar', 'asistente'];

/// Resultado de consultar la ruta de salud de un servicio.
class EstadoServicio {
  const EstadoServicio.conectado(this.servicio) : conectado = true, mensaje = null;

  const EstadoServicio.noDisponible(this.servicio, this.mensaje) : conectado = false;

  final String servicio;
  final bool conectado;
  final String? mensaje;
}

/// Pantalla que comprueba que la app llega a los 4 servicios a través del gateway.
class EstadoScreen extends StatefulWidget {
  const EstadoScreen({super.key, required this.api, required this.apiUrl});

  final ApiClient api;

  /// URL base del gateway, solo para mostrarla.
  final String apiUrl;

  @override
  State<EstadoScreen> createState() => _EstadoScreenState();
}

class _EstadoScreenState extends State<EstadoScreen> {
  List<EstadoServicio>? _estados;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  Future<void> _consultar() async {
    setState(() => _cargando = true);
    final estados = await Future.wait(serviciosMonitoreados.map(_consultarServicio));
    if (!mounted) return;
    setState(() {
      _estados = estados;
      _cargando = false;
    });
  }

  Future<EstadoServicio> _consultarServicio(String servicio) async {
    try {
      final datos = await widget.api.getJson('/api/$servicio/health/');
      if (datos['ok'] == true) return EstadoServicio.conectado(servicio);
      return EstadoServicio.noDisponible(servicio, 'El servicio reportó que no está listo.');
    } on ApiException catch (e) {
      return EstadoServicio.noDisponible(servicio, e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estados = _estados;
    return Scaffold(
      appBar: AppBar(title: const Text('Estado de los servicios')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Gateway: ${widget.apiUrl}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (estados == null)
            const Center(child: CircularProgressIndicator())
          else
            for (final estado in estados) _TarjetaServicio(estado: estado),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _cargando ? null : _consultar,
              icon: _cargando
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaServicio extends StatelessWidget {
  const _TarjetaServicio({required this.estado});

  final EstadoServicio estado;

  @override
  Widget build(BuildContext context) {
    final color = estado.conectado ? Colors.green : Colors.red;
    return Card(
      child: ListTile(
        leading: Icon(estado.conectado ? Icons.check_circle : Icons.error, color: color),
        title: Text(estado.servicio),
        subtitle: Text(estado.conectado ? 'Conectado' : 'No disponible: ${estado.mensaje}'),
      ),
    );
  }
}
