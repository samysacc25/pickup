import 'package:flutter/material.dart';
import '../theme/go_pickup_theme.dart';

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

String textoError(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}
