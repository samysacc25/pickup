import 'package:flutter/material.dart';
import '../theme/go_pickup_theme.dart';
import '../theme/responsive.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../widgets/notificacion.dart';
import 'cliente/home_cliente_screen.dart';
import 'conductor/home_conductor_screen.dart';
import 'conductor/pendiente_aprobacion_screen.dart';
import 'registro_seleccion_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  final _authService = AuthService();

  bool _cargando = false;
  String? _error;

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final sesion = await _authService.iniciarSesion(correo: _correoCtrl.text.trim(), clave: _claveCtrl.text);
      if (!mounted) return;

      Widget destino;
      if (sesion.esConductor) {
        final aprobado = sesion.estadoSolicitudConductor == 'Aprobada' || sesion.estadoSolicitudConductor == '2';
        destino = aprobado ? HomeConductorScreen(sesion: sesion) : PendienteAprobacionScreen(sesion: sesion);
      } else {
        destino = HomeClienteScreen(sesion: sesion);
      }

      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => destino));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      mostrarError(context, textoError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ContenedorResponsivo(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                //const Icon(Icons.local_shipping, color: GoPickupColors.verde, size: 56),
                Image.asset(
                  'assets/iconopickUp.png',
                  width: 180,
                  height: 180,
                ),
                const SizedBox(height: 4),
               /* const Text('GO', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: GoPickupColors.verde)),
                const Text('PICKUP', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2, color: GoPickupColors.verdeOscuro)),
                */const SizedBox(height: 32),
                if (_error != null)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                TextFormField(
                  controller: _correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
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
                  onPressed: _cargando ? null : _iniciarSesion,
                  child: _cargando
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Ingresar'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistroSeleccionScreen())),
                  child: const Text('¿No tienes cuenta? Regístrate'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
