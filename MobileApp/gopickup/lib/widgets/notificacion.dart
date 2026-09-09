import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/go_pickup_theme.dart';

// Abre el marcador del teléfono con el número indicado. Se usa tanto en la
// pantalla del cliente (para llamar al conductor) como en la del conductor
// (para llamar al cliente) -- cada pantalla ya pasa el número correcto de la
// otra persona, aquí solo falta abrir el marcador.
Future<void> llamarA(BuildContext context, String? telefono) async {
  if (telefono == null || telefono.trim().isEmpty) {
    mostrarError(context, 'No hay un número de teléfono disponible.');
    return;
  }

  final uri = Uri(scheme: 'tel', path: telefono.trim());
  final abierto = await launchUrl(uri);
  if (!abierto && context.mounted) {
    mostrarError(context, 'No se pudo abrir el marcador de teléfono.');
  }
}

void mostrarError(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFDC2626),
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(mensaje, style: const TextStyle(color: Colors.white))),
        ],
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}

void mostrarExito(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: GoPickupColors.verdeOscuro,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(mensaje, style: const TextStyle(color: Colors.white))),
        ],
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

// Antes esto solo le sacaba el prefijo "Exception: " al mensaje, pero si el
// error era otro tipo (FormatException, SocketException, etc. -- por ejemplo
// cuando el servidor responde algo que no es el JSON esperado, como una
// página de error vacía mientras Azure se está reiniciando) se mostraba el
// texto técnico crudo tal cual, cosa que ya pasó y confundía. Ahora se
// reconocen esos casos comunes y se muestra un aviso entendible.
String textoError(Object error) {
  final texto = error.toString();

  if (texto.startsWith('Exception: ')) return texto.replaceFirst('Exception: ', '');

  if (error is FormatException || texto.contains('FormatException')) {
    return 'El servidor no respondió correctamente. Intenta de nuevo en unos segundos.';
  }
  if (texto.contains('SocketException') || texto.contains('ClientException') || texto.contains('HandshakeException')) {
    return 'No se pudo conectar al servidor. Revisa tu conexión a internet.';
  }

  return texto;
}
