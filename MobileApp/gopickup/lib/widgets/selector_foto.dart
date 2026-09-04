import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/go_pickup_theme.dart';

class SelectorFoto extends StatelessWidget {
  final String etiqueta;
  final File? archivo;
  final ValueChanged<File> onFotoSeleccionada;
  final bool circular;

  const SelectorFoto({
    super.key,
    required this.etiqueta,
    required this.archivo,
    required this.onFotoSeleccionada,
    this.circular = false,
  });

  Future<void> _elegirOrigen(BuildContext context) async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: GoPickupColors.verde),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: GoPickupColors.verde),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (origen == null) return;

    try {
      final picker = ImagePicker();
      final XFile? imagen = await picker.pickImage(source: origen, imageQuality: 85, maxWidth: 1920);
      if (imagen != null) {
        onFotoSeleccionada(File(imagen.path));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la cámara/galería. Revisa los permisos de la app.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contenido = archivo != null
        ? Image.file(archivo!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
        : Container(
            color: GoPickupColors.grisFondo,
            child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 28),
          );

    return GestureDetector(
      onTap: () => _elegirOrigen(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(circular ? 100 : 10),
            child: Container(
              width: circular ? 90 : double.infinity,
              height: circular ? 90 : 100,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
              child: contenido,
            ),
          ),
        ],
      ),
    );
  }
}
