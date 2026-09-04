import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/responsive.dart';
import '../../services/auth_service.dart';
import '../../services/archivo_service.dart';
import '../../services/validadores.dart';
import '../../models/solicitud.dart';
import '../../models/licencia.dart';
import '../../widgets/notificacion.dart';
import '../../widgets/selector_foto.dart';
import '../../widgets/modal_verificacion_telefono.dart';
import 'pendiente_aprobacion_screen.dart';

class RegistroConductorScreen extends StatefulWidget {
  const RegistroConductorScreen({super.key});

  @override
  State<RegistroConductorScreen> createState() => _RegistroConductorScreenState();
}

class _RegistroConductorScreenState extends State<RegistroConductorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();

  TipoLicencia _tipoLicencia = TipoLicencia.b;
  TipoCamioneta _tipoCamioneta = TipoCamioneta.pequena;
  final _authService = AuthService();

  File? _fotoPerfil;
  File? _fotoFrontal;
  File? _fotoLateral;
  File? _fotoCabina;
  File? _fotoLicencia;

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

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_telefonoVerificado || _telefonoYaVerificado != _telefonoCtrl.text.trim()) {
      mostrarError(context, 'Debes verificar tu número de teléfono antes de continuar.');
      return;
    }

    if (_fotoFrontal == null || _fotoLateral == null || _fotoCabina == null) {
      mostrarError(context, 'Debes subir las 3 fotos del vehículo: frontal, lateral y de la cabina.');
      return;
    }

    if (_fotoLicencia == null) {
      mostrarError(context, 'Debes subir la foto frontal de tu licencia de conducir.');
      return;
    }

    setState(() => _cargando = true);

    try {
      final sesion = await _authService.solicitarSerConductor(
        nombreCompleto: _nombreCtrl.text.trim(),
        correo: _correoCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        clave: _claveCtrl.text,
        numeroCedula: _cedulaCtrl.text.trim(),
        tipoLicencia: _tipoLicencia,
        placa: _placaCtrl.text.trim().toUpperCase(),
        marca: _marcaCtrl.text.trim(),
        modelo: _modeloCtrl.text.trim(),
        color: _colorCtrl.text.trim(),
        anio: int.tryParse(_anioCtrl.text.trim()) ?? 0,
        tipoCamioneta: _tipoCamioneta,
        descripcionCapacidad: _capacidadCtrl.text.trim().isEmpty ? null : _capacidadCtrl.text.trim(),
      );

      final archivoService = ArchivoService(sesion.token);
      final erroresFotos = <String>[];

      Future<void> subir(File? archivo, Future<void> Function() accion, String nombre) async {
        if (archivo == null) return;
        try {
          await accion();
        } catch (e) {
          erroresFotos.add('$nombre: ${textoError(e)}');
        }
      }

      if (_fotoPerfil != null) {
        await subir(_fotoPerfil, () => archivoService.subirFotoPerfil(_fotoPerfil!), 'Foto de perfil');
      }
      await subir(_fotoFrontal, () => archivoService.subirFotoVehiculo(_fotoFrontal!, 'frontal'), 'Foto frontal');
      await subir(_fotoLateral, () => archivoService.subirFotoVehiculo(_fotoLateral!, 'lateral'), 'Foto lateral');
      await subir(_fotoCabina, () => archivoService.subirFotoVehiculo(_fotoCabina!, 'cabina'), 'Foto de cabina');
      await subir(_fotoLicencia, () => archivoService.subirFotoLicencia(_fotoLicencia!), 'Foto de licencia');

      if (!mounted) return;

      if (erroresFotos.isNotEmpty) {
        mostrarError(context, 'Tu solicitud se envió, pero algunas fotos no se pudieron subir. Podrás reintentarlo más tarde.');
      }

      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => PendienteAprobacionScreen(sesion: sesion)), (route) => false);
    } catch (e) {
      if (mounted) mostrarError(context, textoError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiero ser conductor')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContenedorResponsivo(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tu solicitud será revisada por el administrador de Go Pickup. Te avisaremos cuando puedas empezar a recibir viajes.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),

                Center(
                  child: SelectorFoto(
                    etiqueta: 'Tu foto de perfil',
                    archivo: _fotoPerfil,
                    circular: true,
                    onFotoSeleccionada: (f) => setState(() => _fotoPerfil = f),
                  ),
                ),

                const _Titulo('Datos personales'),
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
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : TextButton(onPressed: _verificarTelefono, child: const Text('Verificar')),
                  ),
                  validator: (v) => (v == null || v.trim().length < 7) ? 'Ingresa un teléfono válido' : null,
                ),
                if (!_telefonoVerificado)
                  const Padding(
                    padding: EdgeInsets.only(top: 6, left: 4),
                    child: Text('Debes verificar tu número antes de continuar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _claveCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cedulaCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  decoration: const InputDecoration(labelText: 'Número de cédula', prefixIcon: Icon(Icons.badge_outlined), counterText: ''),
                  validator: (v) => !esCedulaEcuatorianaValida(v) ? 'Ingresa una cédula ecuatoriana válida' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TipoLicencia>(
                  value: _tipoLicencia,
                  decoration: const InputDecoration(labelText: 'Tipo de licencia', prefixIcon: Icon(Icons.contact_page_outlined)),
                  items: TipoLicencia.values.map((t) => DropdownMenuItem(value: t, child: Text('Tipo ${textoTipoLicencia(t)}'))).toList(),
                  onChanged: (valor) => setState(() => _tipoLicencia = valor ?? TipoLicencia.b),
                ),
                const SizedBox(height: 12),
                SelectorFoto(
                  etiqueta: 'Foto frontal de tu licencia de conducir',
                  archivo: _fotoLicencia,
                  onFotoSeleccionada: (f) => setState(() => _fotoLicencia = f),
                ),

                const _Titulo('Datos de tu camioneta'),
                TextFormField(
                  controller: _placaCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Placa', prefixIcon: Icon(Icons.pin_outlined)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la placa' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _marcaCtrl,
                        decoration: const InputDecoration(labelText: 'Marca'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _modeloCtrl,
                        decoration: const InputDecoration(labelText: 'Modelo'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _colorCtrl, decoration: const InputDecoration(labelText: 'Color'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _anioCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Año'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TipoCamioneta>(
                  value: _tipoCamioneta,
                  decoration: const InputDecoration(labelText: 'Tipo de camioneta', prefixIcon: Icon(Icons.local_shipping_outlined)),
                  items: TipoCamioneta.values.map((t) => DropdownMenuItem(value: t, child: Text(textoTipoCamioneta(t)))).toList(),
                  onChanged: (valor) => setState(() => _tipoCamioneta = valor ?? TipoCamioneta.pequena),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _capacidadCtrl,
                  decoration: const InputDecoration(labelText: 'Capacidad aproximada (opcional)', hintText: 'Ej. hasta 1.5 toneladas'),
                ),

                const _Titulo('Fotos del vehículo (obligatorias)'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SelectorFoto(etiqueta: 'Frontal', archivo: _fotoFrontal, onFotoSeleccionada: (f) => setState(() => _fotoFrontal = f))),
                    const SizedBox(width: 10),
                    Expanded(child: SelectorFoto(etiqueta: 'Lateral', archivo: _fotoLateral, onFotoSeleccionada: (f) => setState(() => _fotoLateral = f))),
                    const SizedBox(width: 10),
                    Expanded(child: SelectorFoto(etiqueta: 'Cabina', archivo: _fotoCabina, onFotoSeleccionada: (f) => setState(() => _fotoCabina = f))),
                  ],
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _cargando ? null : _enviarSolicitud,
                  child: _cargando
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enviar solicitud'),
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

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }
}
