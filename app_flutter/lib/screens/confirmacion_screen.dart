import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pedido.dart';
import '../services/api_client.dart';
import 'catalogo_screen.dart' show formatearNumero, iconoMedio;
import 'rastreo_screen.dart';

/// Pedido registrado: muestra el folio para que el cliente lo guarde.
class ConfirmacionScreen extends StatelessWidget {
  const ConfirmacionScreen({super.key, required this.api, required this.pedido});

  final ApiClient api;
  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Envío registrado')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.check_circle, size: 64, color: tema.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Tu folio es', style: tema.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          SelectableText(
            pedido.folio,
            key: const Key('folio_confirmado'),
            style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pedido.folio));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Folio copiado')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar folio'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Guárdalo para rastrear tu envío.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(iconoMedio(pedido.medio)),
                  title: const Text('Medio'),
                  trailing: Text(pedido.medio),
                ),
                ListTile(
                  leading: const Icon(Icons.speed),
                  title: const Text('Tipo de servicio'),
                  trailing: Text(pedido.tipoServicio),
                ),
                ListTile(
                  leading: const Icon(Icons.scale),
                  title: const Text('Paquete'),
                  trailing: Text(
                    '${formatearNumero(pedido.pesoKg)} kg · '
                    '${formatearNumero(pedido.distanciaKm)} km',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('Fecha límite'),
                  trailing: Text(formatearFecha(pedido.fechaLimite)),
                ),
                ListTile(
                  leading: const Icon(Icons.payments),
                  title: const Text('Costo'),
                  trailing: Text(
                    '\$${pedido.costo.toStringAsFixed(2)} ${pedido.moneda}',
                    style: tema.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => RastreoScreen(api: api, folioInicial: pedido.folio),
              ),
            ),
            icon: const Icon(Icons.travel_explore),
            label: const Text('Rastrear este pedido'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo envío'),
          ),
        ],
      ),
    );
  }
}
