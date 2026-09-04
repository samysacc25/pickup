import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/go_pickup_theme.dart';
import '../services/verificacion_service.dart';
import 'notificacion.dart';

Future<bool?> mostrarModalVerificacionTelefono(BuildContext context, String telefono) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => _ModalVerificacionTelefono(telefono: telefono),
  );
}

class _ModalVerificacionTelefono extends StatefulWidget {
  final String telefono;
  const _ModalVerificacionTelefono({required this.telefono});

  @override
  State<_ModalVerificacionTelefono> createState() => _ModalVerificacionTelefonoState();
}

class _ModalVerificacionTelefonoState extends State<_ModalVerificacionTelefono> {
  final _codigoCtrl = TextEditingController();
  final _servicio = VerificacionService();

  bool _enviando = false;
  bool _confirmando = false;
  int _segundosParaReenviar = 0;
  Timer? _timer;
  String? _error;
  String? _codigoDesarrollo;

  @override
  void initState() {
    super.initState();
    _enviarCodigo();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final resultado = await _servicio.enviarCodigo(widget.telefono);
      final smsEnviado = resultado['smsEnviado'] as bool;
      final codigoDesarrollo = resultado['codigoDesarrollo'] as String?;

      setState(() {
        _codigoDesarrollo = codigoDesarrollo;
        _error = (smsEnviado || codigoDesarrollo != null)
            ? null
            : 'No se pudo enviar el SMS. Revisa la configuración de Twilio en el backend.';
      });
      _iniciarContadorReenvio();
    } catch (e) {
      setState(() => _error = textoError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _iniciarContadorReenvio() {
    setState(() => _segundosParaReenviar = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundosParaReenviar <= 1) {
        t.cancel();
        setState(() => _segundosParaReenviar = 0);
      } else {
        setState(() => _segundosParaReenviar--);
      }
    });
  }

  Future<void> _confirmar() async {
    if (_codigoCtrl.text.trim().length != 6) {
      setState(() => _error = 'Ingresa el código de 6 dígitos.');
      return;
    }

    setState(() {
      _confirmando = true;
      _error = null;
    });

    try {
      await _servicio.confirmarCodigo(widget.telefono, _codigoCtrl.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = textoError(e));
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 16),
          const Icon(Icons.sms_outlined, color: GoPickupColors.verde, size: 40),
          const SizedBox(height: 8),
          const Text('Verifica tu número', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 6),
          Text('Enviamos un código de 6 dígitos por SMS a ${widget.telefono}',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          if (_codigoDesarrollo != null)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.construction, size: 16, color: Colors.orange),
                      SizedBox(width: 6),
                      Text('Modo desarrollo (Twilio no configurado)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_codigoDesarrollo!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _codigoCtrl.text = _codigoDesarrollo!),
                      child: const Text('Usar este código', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _codigoCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _confirmando ? null : _confirmar,
            child: _confirmando
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Confirmar código'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: (_enviando || _segundosParaReenviar > 0) ? null : _enviarCodigo,
            child: Text(_segundosParaReenviar > 0 ? 'Reenviar código en $_segundosParaReenviar s' : 'Reenviar código'),
          ),
        ],
      ),
    );
  }
}
