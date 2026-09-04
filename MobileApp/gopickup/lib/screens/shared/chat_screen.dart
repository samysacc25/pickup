import 'package:flutter/material.dart';
import '../../theme/go_pickup_theme.dart';
import '../../services/solicitud_hub_service.dart';
import '../../services/solicitud_service.dart';

// Chat interno de una solicitud activa. Los mensajes viven SOLO en memoria
// (esta lista se pierde al cerrar la pantalla) y se retransmiten en vivo por
// SignalR: nunca se guardan en la base de datos ni en el celular.
class ChatScreen extends StatefulWidget {
  final SolicitudHubService hubService;
  final SolicitudService solicitudService;
  final int solicitudId;
  final String miRol; // "cliente" o "conductor"
  final String nombreOtraPersona;

  const ChatScreen({
    super.key,
    required this.hubService,
    required this.solicitudService,
    required this.solicitudId,
    required this.miRol,
    required this.nombreOtraPersona,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<MensajeChat> _mensajes = [];
  final _mensajeCtrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _enviando = false;

  void agregarMensajeRecibido(MensajeChat mensaje) {
    if (!mounted) return;
    setState(() => _mensajes.add(mensaje));
    _scrollAlFinal();
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _mensajeCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() {
      _enviando = true;
      _mensajes.add(MensajeChat(remitente: widget.miRol, texto: texto, fecha: DateTime.now()));
    });
    _mensajeCtrl.clear();
    _scrollAlFinal();

    try {
      await widget.hubService.enviarMensajeChat(widget.solicitudId, widget.miRol, texto);
    } catch (_) {
      // Respaldo por HTTP normal si el hub en tiempo real no está disponible.
      try {
        await widget.solicitudService.enviarMensajeChat(widget.solicitudId, texto);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreOtraPersona),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Este chat no se guarda — es solo mientras dura el servicio',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85)),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _mensajes.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Escribe algo para coordinar el punto de recogida o cualquier detalle del servicio.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _mensajes.length,
                    itemBuilder: (context, i) {
                      final m = _mensajes[i];
                      final esMio = m.remitente == widget.miRol;
                      return Align(
                        alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: esMio ? GoPickupColors.verde : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                          ),
                          child: Text(
                            m.texto,
                            style: TextStyle(color: esMio ? Colors.white : GoPickupColors.grisTexto),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensajeCtrl,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: GoPickupColors.verde,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _enviar,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
