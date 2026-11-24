import 'dart:async';

import 'package:flutter/material.dart';

import '../models/medio_entrega.dart';
import '../services/api_client.dart';
import '../services/aviso_error.dart';
import 'medio_detalle_screen.dart';

/// Máximo de caracteres de búsqueda que acepta el servidor (docs/api.md).
const int busquedaMaxCaracteres = 100;

/// Espera después de la última tecla antes de buscar.
const Duration esperaBusqueda = Duration(milliseconds: 400);

/// Catálogo de medios de entrega con búsqueda por nombre y descripción.
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final _busqueda = TextEditingController();
  Timer? _temporizador;

  List<MedioEntrega>? _medios;
  AvisoError? _error;
  bool _cargando = false;

  /// Texto de la última búsqueda enviada, para el mensaje de lista vacía.
  String _consultaActual = '';

  /// Cuenta las búsquedas para ignorar respuestas viejas que lleguen tarde.
  int _numeroConsulta = 0;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  void _alEscribir(String _) {
    _temporizador?.cancel();
    _temporizador = Timer(esperaBusqueda, _buscar);
  }

  void _alEnviar(String _) {
    _temporizador?.cancel();
    _buscar();
  }

  void _limpiar() {
    _temporizador?.cancel();
    _busqueda.clear();
    _buscar();
  }

  Future<void> _buscar() async {
    final consulta = _busqueda.text.trim();
    final numero = ++_numeroConsulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final medios = await widget.api.listarMedios(q: consulta);
      if (!mounted || numero != _numeroConsulta) return;
      setState(() {
        _medios = medios;
        _consultaActual = consulta;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted || numero != _numeroConsulta) return;
      setState(() {
        _error = AvisoError.de(e, funcion: 'El catálogo');
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _busqueda,
              maxLength: busquedaMaxCaracteres,
              textInputAction: TextInputAction.search,
              onChanged: _alEscribir,
              onSubmitted: _alEnviar,
              decoration: InputDecoration(
                labelText: 'Buscar medio de entrega',
                hintText: 'Ej. moto, ligeros, ciudad',
                prefixIcon: const Icon(Icons.search),
                counterText: '',
                border: const OutlineInputBorder(),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _busqueda,
                  builder: (context, valor, _) => valor.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          icon: const Icon(Icons.clear),
                          onPressed: _limpiar,
                        ),
                ),
              ),
            ),
          ),
          Expanded(child: _contenido()),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _error;
    if (error != null) {
      return _Aviso(
        icono: Icons.cloud_off,
        titulo: error.titulo,
        mensaje: error.mensaje,
        accion: error.reintentable
            ? FilledButton.icon(
                onPressed: _buscar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              )
            : null,
      );
    }

    final medios = _medios ?? const <MedioEntrega>[];
    if (medios.isEmpty) {
      return _Aviso(
        icono: Icons.search_off,
        titulo: 'Sin resultados',
        mensaje: _consultaActual.isEmpty
            ? 'El catálogo no tiene medios de entrega.'
            : 'No hay medios que coincidan con "$_consultaActual".',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: medios.length,
      itemBuilder: (context, i) {
        final medio = medios[i];
        return Card(
          child: ListTile(
            leading: Icon(iconoMedio(medio.clave)),
            title: Text(medio.nombre),
            subtitle: Text(
              '${medio.descripcion}\n'
              'Hasta ${formatearNumero(medio.pesoMaxKg)} kg · '
              '${formatearNumero(medio.distanciaMaxKm)} km',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MedioDetalleScreen(api: widget.api, clave: medio.clave),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Icono para cada clave del catálogo; uno genérico si llega una clave nueva.
IconData iconoMedio(String clave) {
  return switch (clave) {
    'camioneta' => Icons.local_shipping,
    'motocicleta' => Icons.two_wheeler,
    'bicicleta' => Icons.pedal_bike,
    'dron' => Icons.flight,
    _ => Icons.inventory_2,
  };
}

/// Muestra `20` en vez de `20.0`, pero conserva decimales reales (`4.5`).
String formatearNumero(double valor) {
  return valor == valor.roundToDouble() ? valor.toStringAsFixed(0) : valor.toString();
}

/// Mensaje centrado para los estados de error y lista vacía.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.titulo, required this.mensaje, this.accion});

  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final accion = this.accion;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(mensaje, textAlign: TextAlign.center),
            if (accion != null) ...[const SizedBox(height: 16), accion],
          ],
        ),
      ),
    );
  }
}
