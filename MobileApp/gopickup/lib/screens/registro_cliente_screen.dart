import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/go_pickup_theme.dart';
import '../theme/responsive.dart';
import '../services/auth_service.dart';
import '../services/archivo_service.dart';
import '../services/validadores.dart';
import '../widgets/notificacion.dart';
import '../widgets/selector_foto.dart';
import '../widgets/modal_verificacion_telefono.dart';
import 'cliente/home_cliente_screen.dart';

class RegistroClienteScreen extends StatefulWidget {
  const RegistroClienteScreen({super.key});

  @override
  State<RegistroClienteScreen> createState() => _RegistroClienteScreenState();
}

class _RegistroClienteScreenState extends State<RegistroClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  final _authService = AuthService();

  File? _fotoPerfil;
  bool _cargando = false;
  bool _telefonoVerificado = false;
  String? _telefonoYaVerificado;

  Future<void> _verificarTelefono() async {
    final telefono = _telefonoCtrl.text.trim();
    if (telefono.length < 7) {
      mostrarError(context, 'Ingresa un número de teléfono válido antes de verificarlo.');
      return;
    }

    final resultado = await mostrarModalVerificacionTelefono(context, telefono);
    if (resultado == true) {
      setState(() {
        _telefonoVerificado = true;
        _telefonoYaVerificado = telefono;
      });
      if (mounted) mostrarExito(context, 'Teléfono verificado correctamente.');
    }
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_telefonoVerificado || _telefonoYaVerificado != _telefonoCtrl.text.trim()) {
      mostrarError(context, 'Debes verificar tu número de teléfono antes de registrarte.');
      return;
    }

    setState(() => _cargando = true);

    try {
      final sesion = await _authService.registrarCliente(
        nombreCompleto: _nombreCtrl.text.trim(),
        correo: _correoCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        clave: _claveCtrl.text,
      );

      if (_fotoPerfil != null) {
        try {
          await ArchivoService(sesion.token).subirFotoPerfil(_fotoPerfil!);
        } catch (e) {
          if (mounted) mostrarError(context, 'Tu cuenta se creó, pero la foto no se pudo subir: ${textoError(e)}');
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeClienteScreen(sesion: sesion)), (route) => false);
    } catch (e) {
      if (mounted) mostrarError(context, textoError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta de cliente')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContenedorResponsivo(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SelectorFoto(
                    etiqueta: 'Foto de perfil (opcional)',
                    archivo: _fotoPerfil,
                    circular: true,
                    onFotoSeleccionada: (f) => setState(() => _fotoPerfil = f),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Ingresa tu nombre completo' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => !esCorreoValido(v) ? 'Ingresa un correo válido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  onChanged: (v) {
                    if (_telefonoVerificado && v.trim() != _telefonoYaVerificado) setState(() => _telefonoVerificado = false);
                  },
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    suffixIcon: _telefonoVerificado
                        ? const Icon(Icons.check_circle, color: GoPickupColors.verde)
                        : TextButton(onPressed: _verificarTelefono, child: const Text('Verificar')),
                  ),
                  validator: (v) => (v == null || v.trim().length < 7) ? 'Ingresa un teléfono válido' : null,
                ),
                if (!_telefonoVerificado)
                  const Padding(
                    padding: EdgeInsets.only(top: 6, left: 4),
                    child: Text('Debes verificar tu número antes de registrarte', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _claveCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _cargando ? null : _registrar,
                  child: _cargando
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Registrarme'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
