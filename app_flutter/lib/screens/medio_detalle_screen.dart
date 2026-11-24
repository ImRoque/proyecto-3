import 'package:flutter/material.dart';

import '../models/medio_entrega.dart';
import '../services/api_client.dart';
import '../services/aviso_error.dart';
import 'catalogo_screen.dart' show formatearNumero, iconoMedio;

/// Detalle de un medio de entrega, consultado por su clave.
class MedioDetalleScreen extends StatefulWidget {
  const MedioDetalleScreen({super.key, required this.api, required this.clave});

  final ApiClient api;
  final String clave;

  @override
  State<MedioDetalleScreen> createState() => _MedioDetalleScreenState();
}

class _MedioDetalleScreenState extends State<MedioDetalleScreen> {
  MedioEntrega? _medio;
  AvisoError? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final medio = await widget.api.obtenerMedio(widget.clave);
      if (!mounted) return;
      setState(() {
        _medio = medio;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AvisoError.de(e, funcion: 'El catálogo');
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final medio = _medio;
    return Scaffold(
      appBar: AppBar(title: Text(medio?.nombre ?? 'Detalle')),
      body: _cuerpo(context, medio),
    );
  }

  Widget _cuerpo(BuildContext context, MedioEntrega? medio) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null || medio == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error?.titulo ?? 'No se pudo cargar el medio',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(error?.mensaje ?? '', textAlign: TextAlign.center),
              if (error == null || error.reintentable) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(iconoMedio(medio.clave), size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text(medio.descripcion)),
          ],
        ),
        const SizedBox(height: 16),
        _Dato('Peso máximo', '${formatearNumero(medio.pesoMaxKg)} kg'),
        _Dato('Distancia máxima', '${formatearNumero(medio.distanciaMaxKm)} km'),
        _Dato('Velocidad promedio', '${formatearNumero(medio.velocidadKmh)} km/h'),
        _Dato('Costo base', '\$${medio.costoBase.toStringAsFixed(2)} MXN'),
        _Dato('Costo por km', '\$${medio.costoPorKm.toStringAsFixed(2)} MXN'),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(etiqueta),
      trailing: Text(valor, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
