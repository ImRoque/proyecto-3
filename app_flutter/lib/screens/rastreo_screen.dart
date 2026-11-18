import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../services/api_client.dart';
import 'catalogo_screen.dart' show iconoMedio;

/// Consulta un pedido por folio y muestra en qué paso va.
class RastreoScreen extends StatefulWidget {
  const RastreoScreen({super.key, required this.api, this.folioInicial});

  final ApiClient api;

  /// Si viene, se consulta al abrir la pantalla (por ejemplo, desde la confirmación).
  final String? folioInicial;

  @override
  State<RastreoScreen> createState() => _RastreoScreenState();
}

class _RastreoScreenState extends State<RastreoScreen> {
  final _formulario = GlobalKey<FormState>();
  late final _folio = TextEditingController(text: widget.folioInicial ?? '');

  bool _cargando = false;
  PedidoResumen? _pedido;

  /// Folio consultado que no existe (404).
  String? _noEncontrado;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.folioInicial != null) _consultar();
  }

  @override
  void dispose() {
    _folio.dispose();
    super.dispose();
  }

  Future<void> _consultar() async {
    if (_cargando) return;
    final folio = normalizarFolio(_folio.text);
    // En initState el formulario aún no existe; el folio inicial ya viene validado.
    if (folio == null) {
      _formulario.currentState?.validate();
      return;
    }
    setState(() {
      _cargando = true;
      _pedido = null;
      _noEncontrado = null;
      _error = null;
    });
    try {
      final pedido = await widget.api.consultarPedido(folio);
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        if (e.codigoHttp == 404) {
          _noEncontrado = folio;
        } else {
          _error = e.mensaje;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rastrear envío')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formulario,
            child: TextFormField(
              controller: _folio,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => _consultar(),
              decoration: InputDecoration(
                labelText: 'Folio',
                hintText: 'PQ-20261117-7KQ3',
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Consultar',
                  icon: const Icon(Icons.search),
                  onPressed: _cargando ? null : _consultar,
                ),
              ),
              validator: (texto) => normalizarFolio(texto ?? '') == null
                  ? 'El folio tiene el formato PQ-AAAAMMDD-XXXX'
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          _resultado(context),
        ],
      ),
    );
  }

  Widget _resultado(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final noEncontrado = _noEncontrado;
    if (noEncontrado != null) {
      return _Aviso(
        icono: Icons.search_off,
        titulo: 'Folio no encontrado',
        mensaje: 'No existe un pedido con el folio $noEncontrado. Revisa que esté bien escrito.',
      );
    }
    final error = _error;
    if (error != null) {
      return _Aviso(
        icono: Icons.cloud_off,
        titulo: 'No se pudo consultar el pedido',
        mensaje: error,
        accion: FilledButton.icon(
          onPressed: _consultar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }
    final pedido = _pedido;
    if (pedido == null) {
      return const _Aviso(
        icono: Icons.travel_explore,
        titulo: 'Escribe tu folio',
        mensaje: 'Lo recibiste al registrar tu envío.',
      );
    }
    return _DetallePedido(pedido: pedido);
  }
}

class _DetallePedido extends StatelessWidget {
  const _DetallePedido({required this.pedido});

  final PedidoResumen pedido;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(pedido.folio, style: tema.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        LineaEstados(estado: pedido.estado),
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
                leading: const Icon(Icons.event),
                title: const Text('Fecha límite'),
                trailing: Text(formatearFecha(pedido.fechaLimite)),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Última actualización'),
                trailing: Text(formatearFechaHora(pedido.actualizadoEn)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Texto para mostrar de cada estado del contrato.
String nombreEstado(String estado) => switch (estado) {
  estadoCreado => 'Creado',
  estadoEnCamino => 'En camino',
  estadoEntregado => 'Entregado',
  estadoCancelado => 'Cancelado',
  _ => estado,
};

/// Línea de estados `CREADO → EN_CAMINO → ENTREGADO` con el paso actual marcado.
///
/// Un pedido `CANCELADO` (solo puede venir de `CREADO`) muestra Creado y después Cancelado.
class LineaEstados extends StatelessWidget {
  const LineaEstados({super.key, required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final cancelado = estado == estadoCancelado;
    final pasos = cancelado ? const [estadoCreado, estadoCancelado] : lineaEstados;
    final actual = pasos.indexOf(estado);

    final hijos = <Widget>[];
    for (var i = 0; i < pasos.length; i++) {
      final hecho = i <= actual;
      final color = !hecho
          ? colores.outlineVariant
          : (cancelado && i == actual ? colores.error : colores.primary);
      if (i > 0) {
        hijos.add(
          Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 28),
              color: hecho ? color : colores.outlineVariant,
            ),
          ),
        );
      }
      hijos.add(
        Column(
          key: Key('paso_${pasos[i]}'),
          children: [
            Icon(
              i == actual
                  ? (cancelado ? Icons.cancel : Icons.radio_button_checked)
                  : (hecho ? Icons.check_circle : Icons.radio_button_unchecked),
              color: color,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              nombreEstado(pasos[i]),
              style: TextStyle(
                color: hecho ? colores.onSurface : colores.outline,
                fontWeight: i == actual ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      label: 'Estado del pedido: ${nombreEstado(estado)}',
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: hijos),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.titulo, required this.mensaje, this.accion});

  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final accion = this.accion;
    return Column(
      children: [
        Icon(icono, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(mensaje, textAlign: TextAlign.center),
        if (accion != null) ...[const SizedBox(height: 16), accion],
      ],
    );
  }
}
