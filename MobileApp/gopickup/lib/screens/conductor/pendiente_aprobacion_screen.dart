import 'package:flutter/material.dart';
import '../../theme/go_pickup_theme.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';

class PendienteAprobacionScreen extends StatelessWidget {
  final SesionUsuario sesion;
  const PendienteAprobacionScreen({super.key, required this.sesion});

  bool get _fueRechazado => sesion.estadoSolicitudConductor == 'Rechazada' || sesion.estadoSolicitudConductor == '3';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_fueRechazado ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                  color: _fueRechazado ? Colors.red : GoPickupColors.verde, size: 72),
              const SizedBox(height: 20),
              Text(_fueRechazado ? 'Tu solicitud fue rechazada' : 'Tu solicitud está en revisión',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                _fueRechazado
                    ? 'El administrador de Go Pickup revisó tus datos y no fueron aprobados. Puedes contactar a soporte para más información.'
                    : 'Gracias por registrarte, ${sesion.nombreCompleto.split(' ').first}. El administrador de Go Pickup está revisando tus datos y los de tu camioneta. Te notificaremos apenas puedas empezar a recibir solicitudes.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () async {
                  await AuthService().cerrarSesion();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                },
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
