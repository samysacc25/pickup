import 'package:flutter/material.dart';

// Campo de contraseña reutilizable con el ícono de ojo para mostrar/ocultar
// la clave mientras se escribe. Se usa en login y en los dos registros
// (cliente y conductor) en vez de repetir el mismo TextFormField tres veces.
class CampoClave extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;

  const CampoClave({
    super.key,
    required this.controller,
    this.labelText = 'Contraseña',
    this.validator,
  });

  @override
  State<CampoClave> createState() => _CampoClaveState();
}

class _CampoClaveState extends State<CampoClave> {
  bool _verClave = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: !_verClave,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
          onPressed: () => setState(() => _verClave = !_verClave),
        ),
      ),
      validator: widget.validator,
    );
  }
}
