import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/go_pickup_theme.dart';
import '../theme/responsive.dart';
import '../services/auth_service.dart';
import '../widgets/notificacion.dart';
import '../widgets/campo_clave.dart';

// Reseteo de contraseña ingresando solo el número de teléfono: se verifica a
// qué cuenta pertenece (mostrando el primer nombre para que la persona
// confirme que es la suya), se envía un código SMS, y al confirmarlo se deja
// establecer la nueva contraseña. Reusa la misma tabla/servicio de códigos
// de verificación que ya existía para el registro (ver AuthController en el
// backend, endpoints reset-clave/solicitar y reset-clave/confirmar).
class RestablecerClaveScreen extends StatefulWidget {
  const RestablecerClaveScreen({super.key});

  @override
  State<RestablecerClaveScreen> createState() => _RestablecerClaveScreenState();
}

enum _PasoReset { telefono, codigo, nuevaClave }

class _RestablecerClaveScreenState extends State<RestablecerClaveScreen> {
  final _authService = AuthService();

  final _telefonoCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  final _confirmarClaveCtrl = TextEditingController();
  final _formClaveKey = GlobalKey<FormState>();

  _PasoReset _paso = _PasoReset.telefono;
  bool _cargando = false;
  String? _error;
  String? _nombreCuenta;
  String? _codigoDesarrollo;
  int _segundosParaReenviar = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _telefonoCtrl.dispose();
    _codigoCtrl.dispose();
    _claveCtrl.dispose();
    _confirmarClaveCtrl.dispose();
    super.dispose();
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

  Future<void> _solicitarCodigo() async {
    final telefono = _telefonoCtrl.text.trim();
    if (telefono.isEmpty) {
      setState(() => _error = 'Ingresa tu número de teléfono.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final resultado = await _authService.solicitarResetClave(telefono);
      setState(() {
        _nombreCuenta = resultado['nombre'] as String?;
        _codigoDesarrollo = resultado['codigoDesarrollo'] as String?;
        _paso = _PasoReset.codigo;
      });
      _iniciarContadorReenvio();
    } catch (e) {
      setState(() => _error = textoError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reenviarCodigo() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultado = await _authService.solicitarResetClave(_telefonoCtrl.text.trim());
      setState(() => _codigoDesarrollo = resultado['codigoDesarrollo'] as String?);
      _iniciarContadorReenvio();
    } catch (e) {
      setState(() => _error = textoError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _confirmarCodigoYContinuar() {
    if (_codigoCtrl.text.trim().length != 6) {
      setState(() => _error = 'Ingresa el código de 6 dígitos.');
      return;
    }
    setState(() {
      _error = null;
      _paso = _PasoReset.nuevaClave;
    });
  }

  Future<void> _guardarNuevaClave() async {
    if (!_formClaveKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await _authService.confirmarResetClave(
        _telefonoCtrl.text.trim(),
        _codigoCtrl.text.trim(),
        _claveCtrl.text,
      );
      if (!mounted) return;
      mostrarExito(context, 'Tu contraseña se actualizó correctamente. Ya puedes iniciar sesión.');
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = textoError(e);
        // Si el código resultó incorrecto/expirado, se regresa al paso del
        // código para que la persona pueda corregirlo o pedir uno nuevo, en
        // vez de quedarse atascada en el paso de la nueva contraseña.
        _paso = _PasoReset.codigo;
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContenedorResponsivo(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  switch (_paso) {
                    _PasoReset.telefono => _pasoTelefono(),
                    _PasoReset.codigo => _pasoCodigo(),
                    _PasoReset.nuevaClave => _pasoNuevaClave(),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pasoTelefono() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset, color: GoPickupColors.verde, size: 48),
        const SizedBox(height: 12),
        const Text('¿Olvidaste tu contraseña?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 6),
        const Text(
          'Ingresa el número de teléfono con el que te registraste. Verificaremos a qué cuenta pertenece y te enviaremos un código para restablecer tu contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _telefonoCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Número de teléfono', prefixIcon: Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _cargando ? null : _solicitarCodigo,
          child: _cargando
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Enviar código'),
        ),
      ],
    );
  }

  Widget _pasoCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.sms_outlined, color: GoPickupColors.verde, size: 48),
        const SizedBox(height: 12),
        Text(
          _nombreCuenta != null ? 'Hola, $_nombreCuenta' : 'Verifica tu identidad',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 6),
        Text(
          'Enviamos un código de 6 dígitos por SMS al ${_telefonoCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
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
                const Text('Código de verificación (modo desarrollo)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
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
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _cargando ? null : _confirmarCodigoYContinuar,
          child: const Text('Continuar'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: (_cargando || _segundosParaReenviar > 0) ? null : _reenviarCodigo,
          child: Text(_segundosParaReenviar > 0 ? 'Reenviar código en $_segundosParaReenviar s' : 'Reenviar código'),
        ),
        TextButton(
          onPressed: _cargando ? null : () => setState(() { _paso = _PasoReset.telefono; _error = null; }),
          child: const Text('Cambiar número de teléfono'),
        ),
      ],
    );
  }

  Widget _pasoNuevaClave() {
    return Form(
      key: _formClaveKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.password_outlined, color: GoPickupColors.verde, size: 48),
          const SizedBox(height: 12),
          const Text('Crea tu nueva contraseña', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          CampoClave(
            controller: _claveCtrl,
            labelText: 'Nueva contraseña',
            validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: 12),
          CampoClave(
            controller: _confirmarClaveCtrl,
            labelText: 'Confirmar contraseña',
            validator: (v) => (v != _claveCtrl.text) ? 'Las contraseñas no coinciden' : null,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _cargando ? null : _guardarNuevaClave,
            child: _cargando
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Guardar nueva contraseña'),
          ),
        ],
      ),
    );
  }
}
