import 'package:flutter/material.dart';
import '../theme/go_pickup_theme.dart';
import '../theme/responsive.dart';

// Pantalla de Términos y Condiciones / protección de datos, que se muestra
// después de llenar el formulario de registro (cliente o conductor) y antes
// de crear la cuenta. La persona debe marcar el checkbox de aceptación para
// poder continuar -- solo entonces se llama al backend para registrar la
// cuenta. Se reutiliza para ambos flujos de registro.
//
// Devuelve `true` (vía Navigator.pop) si la persona aceptó y presionó
// "Aceptar y continuar"; `null`/`false` si se regresó sin aceptar.
class TerminosCondicionesScreen extends StatefulWidget {
  const TerminosCondicionesScreen({super.key});

  @override
  State<TerminosCondicionesScreen> createState() => _TerminosCondicionesScreenState();
}

class _TerminosCondicionesScreenState extends State<TerminosCondicionesScreen> {
  bool _aceptado = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Términos y condiciones')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: ContenedorResponsivo(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      Icon(Icons.privacy_tip_outlined, color: GoPickupColors.verde, size: 44),
                      SizedBox(height: 12),
                      Text(
                        'Términos y condiciones de uso y protección de datos personales',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      SizedBox(height: 20),
                      _Seccion(
                        titulo: '1. Aceptación de los términos',
                        texto:
                            'Al registrarte y usar Go Pickup aceptas estos términos y condiciones y nuestro tratamiento de datos personales conforme a la Ley Orgánica de Protección de Datos Personales (LOPDP) del Ecuador. Si no estás de acuerdo, no debes continuar con el registro.',
                      ),
                      _Seccion(
                        titulo: '2. Datos que recopilamos',
                        texto:
                            'Para poder ofrecerte el servicio de transporte de carga en camioneta, recopilamos: nombre completo, correo electrónico, número de teléfono, número de cédula (para la seguridad de clientes y conductores), y — si eres conductor — los datos de tu vehículo (placa, marca, modelo, color, año) y tu tipo de licencia. Durante el uso del servicio también procesamos tu ubicación en tiempo real (origen, destino y trayecto del viaje) y los mensajes del chat dentro de un viaje activo.',
                      ),
                      _Seccion(
                        titulo: '3. Finalidad del tratamiento',
                        texto:
                            'Estos datos se usan únicamente para: crear y administrar tu cuenta; conectar a clientes con conductores disponibles; calcular tarifas y rutas; permitir la comunicación entre cliente y conductor durante un viaje; verificar tu identidad por SMS; enviarte notificaciones sobre el estado de tus solicitudes; y cumplir con obligaciones legales o de seguridad (por ejemplo, identificar a las partes de un viaje ante una autoridad competente si fuera necesario).',
                      ),
                      _Seccion(
                        titulo: '4. Con quién se comparte tu información',
                        texto:
                            'Tu nombre, teléfono y (si aplica) placa del vehículo se muestran a la otra parte de un viaje (cliente o conductor) únicamente mientras ese viaje está activo, para que puedan coordinarse. No vendemos ni compartimos tus datos personales con terceros para fines publicitarios. Podemos usar proveedores externos únicamente para el envío de SMS de verificación y notificaciones push, que actúan solo como intermediarios técnicos.',
                      ),
                      _Seccion(
                        titulo: '5. Conservación de la información',
                        texto:
                            'El historial de chat de un viaje se conserva únicamente mientras el viaje sigue activo y se elimina al finalizar o cancelarse. El resto de tu información se conserva mientras mantengas tu cuenta activa, o el tiempo mínimo requerido por la ley aplicable.',
                      ),
                      _Seccion(
                        titulo: '6. Tus derechos',
                        texto:
                            'Como titular de tus datos, tienes derecho a acceder, actualizar, rectificar o solicitar la eliminación de tu información personal, así como a revocar tu consentimiento, contactando al soporte de Go Pickup. Ten en cuenta que algunos datos pueden ser necesarios para poder seguir usando el servicio.',
                      ),
                      _Seccion(
                        titulo: '7. Uso responsable del servicio',
                        texto:
                            'Te comprometes a proporcionar información veraz y actualizada, a usar el servicio de forma responsable, y a mantener un trato respetuoso con clientes, conductores y personal de Go Pickup. El incumplimiento de estos términos puede resultar en la suspensión o eliminación de tu cuenta.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Al marcar la casilla de abajo confirmas que leíste y aceptas estos términos y el tratamiento de tus datos personales descrito aquí.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: ContenedorResponsivo(
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckboxListTile(
                        value: _aceptado,
                        onChanged: (v) => setState(() => _aceptado = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'He leído y acepto los términos y condiciones y el tratamiento de mis datos personales.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: _aceptado ? () => Navigator.of(context).pop(true) : null,
                        child: const Text('Aceptar y siguiente'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final String texto;
  const _Seccion({required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(texto, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
