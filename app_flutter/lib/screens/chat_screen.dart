import 'package:flutter/material.dart';

import '../models/mensaje_chat.dart';
import '../services/api_client.dart';
import '../services/aviso_error.dart';

/// Límite de `mensaje` en docs/api.md. El servidor también lo revisa.
const int largoMaximoMensaje = 500;

/// Conversación con el asistente del comprador.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _texto = TextEditingController();
  final _foco = FocusNode();
  final _desplazamiento = ScrollController();
  final _mensajes = <MensajeChat>[];

  bool _escribiendo = false;

  /// Error del último envío y el mensaje que falló, para reintentar.
  AvisoError? _error;
  String? _pendiente;

  @override
  void initState() {
    super.initState();
    _texto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _texto.dispose();
    _foco.dispose();
    _desplazamiento.dispose();
    super.dispose();
  }

  bool get _puedeEnviar => !_escribiendo && _texto.text.trim().isNotEmpty;

  void _enviarCampo() {
    if (!_puedeEnviar) return;
    final mensaje = _texto.text.trim();
    _texto.clear();
    // Enter quita el foco del campo; se devuelve para seguir escribiendo.
    _foco.requestFocus();
    setState(() => _mensajes.add(MensajeChat.usuario(mensaje)));
    _consultar(mensaje);
  }

  void _reintentar() {
    final pendiente = _pendiente;
    if (pendiente != null && !_escribiendo) _consultar(pendiente);
  }

  Future<void> _consultar(String mensaje) async {
    setState(() {
      _escribiendo = true;
      _error = null;
      _pendiente = null;
    });
    _bajar();
    try {
      final respuesta = await widget.api.enviarMensaje(mensaje);
      if (!mounted) return;
      setState(() {
        _mensajes.add(MensajeChat.asistente(respuesta.respuesta, intencion: respuesta.intencion));
        _escribiendo = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final aviso = AvisoError.de(e, funcion: 'El asistente');
      setState(() {
        _escribiendo = false;
        _error = aviso;
        if (aviso.reintentable) {
          _pendiente = mensaje;
        } else if (_texto.text.isEmpty) {
          // 400: el mensaje vuelve al campo para corregirlo; reintentar lo mismo no sirve.
          _texto.text = mensaje;
        }
      });
    }
    _bajar();
  }

  /// Lleva la lista al último mensaje después de dibujar.
  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_desplazamiento.hasClients) {
        _desplazamiento.animateTo(
          _desplazamiento.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente')),
      body: Column(
        children: [
          Expanded(child: _conversacion(context)),
          if (_error case final error?)
            _AvisoError(aviso: error, alReintentar: error.reintentable ? _reintentar : null),
          _campo(context),
        ],
      ),
    );
  }

  Widget _conversacion(BuildContext context) {
    if (_mensajes.isEmpty && !_escribiendo) {
      return const _Vacio();
    }
    return ListView.builder(
      controller: _desplazamiento,
      padding: const EdgeInsets.all(12),
      itemCount: _mensajes.length + (_escribiendo ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _mensajes.length) return const _Escribiendo();
        return _Burbuja(mensaje: _mensajes[i]);
      },
    );
  }

  Widget _campo(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('campo_mensaje'),
                controller: _texto,
                focusNode: _foco,
                minLines: 1,
                maxLines: 4,
                maxLength: largoMaximoMensaje,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _enviarCampo(),
                decoration: const InputDecoration(
                  hintText: 'Escribe tu mensaje',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Enviar',
              onPressed: _puedeEnviar ? _enviarCampo : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje});

  final MensajeChat mensaje;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final deUsuario = mensaje.deUsuario;
    return Align(
      alignment: deUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          key: Key(deUsuario ? 'burbuja_usuario' : 'burbuja_asistente'),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: deUsuario ? colores.primary : colores.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(deUsuario ? 16 : 4),
              bottomRight: Radius.circular(deUsuario ? 4 : 16),
            ),
          ),
          child: SelectableText(
            mensaje.texto,
            style: TextStyle(color: deUsuario ? colores.onPrimary : colores.onSurface),
          ),
        ),
      ),
    );
  }
}

class _Escribiendo extends StatelessWidget {
  const _Escribiendo();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('escribiendo'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colores.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Escribiendo…', style: TextStyle(color: colores.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  const _AvisoError({required this.aviso, this.alReintentar});

  final AvisoError aviso;

  /// `null` cuando hay que corregir el mensaje en vez de reintentar.
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      key: const Key('aviso_error'),
      width: double.infinity,
      color: colores.errorContainer,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colores.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${aviso.titulo}. ${aviso.mensaje}',
              style: TextStyle(color: colores.onErrorContainer),
            ),
          ),
          if (alReintentar case final reintentar?)
            TextButton(onPressed: reintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.support_agent, size: 48, color: tema.colorScheme.primary),
            const SizedBox(height: 12),
            Text('¿En qué te ayudo?', style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Pregúntame por tu pedido con su folio, qué medio te conviene, '
              'tarifas u horarios.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
