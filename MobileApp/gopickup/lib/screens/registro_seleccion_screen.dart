import 'package:flutter/material.dart';
import '../theme/go_pickup_theme.dart';
import 'registro_cliente_screen.dart';
import 'conductor/registro_conductor_screen.dart';

class RegistroSeleccionScreen extends StatelessWidget {
  const RegistroSeleccionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('¿Cómo quieres usar Go Pickup?',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GoPickupColors.grisTexto)),
            const SizedBox(height: 24),
            _TarjetaOpcion(
              icono: Icons.person_outline,
              titulo: 'Quiero viajar / enviar carga',
              subtitulo: 'Solicita camionetas para transportarte o llevar mercancía',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistroClienteScreen())),
            ),
            const SizedBox(height: 16),
            _TarjetaOpcion(
              icono: Icons.local_shipping_outlined,
              titulo: 'Quiero ser conductor',
              subtitulo: 'Registra tu camioneta. Tu solicitud será revisada por el administrador',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistroConductorScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaOpcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _TarjetaOpcion({required this.icono, required this.titulo, required this.subtitulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GoPickupColors.verde.withOpacity(0.3)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 26, backgroundColor: GoPickupColors.verde.withOpacity(0.12), child: Icon(icono, color: GoPickupColors.verdeOscuro)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(subtitulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: GoPickupColors.verde),
          ],
        ),
      ),
    );
  }
}
