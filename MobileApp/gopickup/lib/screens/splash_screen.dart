import 'package:flutter/material.dart';
import '../theme/go_pickup_theme.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'cliente/home_cliente_screen.dart';
import 'conductor/home_conductor_screen.dart';
import 'conductor/pendiente_aprobacion_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    final sesion = await AuthService().obtenerSesionGuardada();
    if (!mounted) return;

    if (sesion == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => _pantallaSegunRol(sesion)));
  }

  Widget _pantallaSegunRol(SesionUsuario sesion) {
    if (sesion.esConductor) {
      if (sesion.estadoSolicitudConductor == 'Aprobada' || sesion.estadoSolicitudConductor == '2') {
        return HomeConductorScreen(sesion: sesion);
      }
      return PendienteAprobacionScreen(sesion: sesion);
    }
    return HomeClienteScreen(sesion: sesion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoPickupColors.verde,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_shipping, color: Colors.white, size: 64),
            const SizedBox(height: 12),
            const Text('GO', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
            const Text('PICKUP', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 4),
            const Text('Tu transporte confiable', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
