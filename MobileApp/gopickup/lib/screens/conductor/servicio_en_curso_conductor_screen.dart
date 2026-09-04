import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/go_pickup_theme.dart';
import '../../models/usuario.dart';
import '../../models/solicitud.dart';
import '../../services/solicitud_service.dart';
import '../../services/solicitud_hub_service.dart';
import '../../services/conductor_service.dart' as conductor_srv;
import '../../widgets/notificacion.dart';
import '../shared/chat_screen.dart';
import 'home_conductor_screen.dart';

class ServicioEnCursoConductorScreen extends StatefulWidget {
  final SesionUsuario sesion;
  final int solicitudId;

  const ServicioEnCursoConductorScreen({super.key, required this.sesion, required this.solicitudId});

  @override
  State<ServicioEnCursoConductorScreen> createState() => _ServicioEnCursoConductorScreenState();
}

class _ServicioEnCursoConductorScreenState extends State<ServicioEnCursoConductorScreen> {
  late final SolicitudService _solicitudService;
  late final conductor_srv.ConductorService _conductorService;
  late final SolicitudHubService _hubService;
  Timer? _timerUbicacion;

  Solicitud? _solicitud;
  bool _actualizando = false;

  @override
  void initState() {
    super.initState();
    _solicitudService = SolicitudService(widget.sesion.token);
    _conductorService = conductor_srv.ConductorService(widget.sesion.token);
    _hubService = SolicitudHubService(widget.sesion.token);
    _cargar();
    _hubService.conectarYUnirse(
      solicitudId: widget.solicitudId,
      alActualizarSolicitud: (s) {
        if (mounted) setState(() => _solicitud = s);
      },
      alActualizarUbicacion: (_, __) {},
    );
    _timerUbicacion = Timer.periodic(const Duration(seconds: 8), (_) => _reportarUbicacion());
  }

  Future<void> _cargar() async {
    try {
      final s = await _solicitudService.obtenerSolicitud(widget.solicitudId);
      if (mounted) setState(() => _solicitud = s);
    } catch (e) {
      if (mounted) mostrarError(context, textoError(e));
    }
  }

  Future<void> _reportarUbicacion() async {
    try {
      final posicion = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _conductorService.actualizarUbicacion(posicion.latitude, posicion.longitude);
      await _hubService.enviarUbicacion(widget.solicitudId, posicion.latitude, posicion.longitude);
    } catch (_) {}
  }

  void _abrirChat() {
    if (_solicitud == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          hubService: _hubService,
          solicitudService: _solicitudService,
          solicitudId: widget.solicitudId,
          miRol: 'conductor',
          nombreOtraPersona: _solicitud!.clienteNombre,
        ),
      ),
    );
  }

  Future<void> _avanzarEstado() async {
    if (_solicitud == null) return;
    setState(() => _actualizando = true);

    try {
      Solicitud actualizada;
      switch (_solicitud!.estado) {
        case EstadoSolicitud.aceptada:
          actualizada = await _solicitudService.marcarEnCamino(widget.solicitudId);
          break;
        case EstadoSolicitud.enCamino:
          actualizada = await _solicitudService.iniciarServicio(widget.solicitudId);
          break;
        case EstadoSolicitud.iniciada:
          actualizada = await _solicitudService.finalizarServicio(widget.solicitudId);
          await _conductorService.cambiarEstado(conductor_srv.EstadoConductor.disponible);
          break;
        default:
          return;
      }
      if (mounted) setState(() => _solicitud = actualizada);
    } catch (e) {
      if (mounted) mostrarError(context, textoError(e));
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  String _textoBoton(EstadoSolicitud estado) {
    switch (estado) {
      case EstadoSolicitud.aceptada:
        return 'Voy en camino';
      case EstadoSolicitud.enCamino:
        return 'Llegué - Iniciar servicio';
      case EstadoSolicitud.iniciada:
        return 'Finalizar servicio';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _timerUbicacion?.cancel();
    _hubService.desconectar();
    _hubService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _solicitud;
    if (s == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (s.estado == EstadoSolicitud.finalizada) return _pantallaFinalizado(s);
    if (s.estado == EstadoSolicitud.canceladaCliente) return _pantallaCancelado();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicio en curso'),
        actions: [IconButton(icon: const Icon(Icons.chat_bubble_outline), tooltip: 'Chat con el cliente', onPressed: _abrirChat)],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(s.origenLatitud, s.origenLongitud), zoom: 14),
              markers: {
                Marker(
                  markerId: const MarkerId('origen'),
                  position: LatLng(s.origenLatitud, s.origenLongitud),
                  infoWindow: const InfoWindow(title: 'Punto de recogida'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
                Marker(
                  markerId: const MarkerId('destino'),
                  position: LatLng(s.destinoLatitud, s.destinoLongitud),
                  infoWindow: const InfoWindow(title: 'Destino'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(textoEstado(s.estado), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GoPickupColors.verdeOscuro)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(s.clienteNombre),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.chat_bubble_outline, color: GoPickupColors.verde), onPressed: _abrirChat),
                  if (s.clienteTelefono != null)
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: () => llamarA(context, s.clienteTelefono),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(s.llevaCarga ? (s.descripcionCarga ?? 'Con carga adicional') : 'Transporte de pasajero', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Text('\$${(s.tarifaAcordada ?? s.tarifaSugerida).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _actualizando ? null : _avanzarEstado,
                  child: _actualizando
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_textoBoton(s.estado)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pantallaFinalizado(Solicitud s) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicio finalizado')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: GoPickupColors.verde, size: 72),
            const SizedBox(height: 16),
            Text('Total cobrado: \$${(s.tarifaFinal ?? s.tarifaAcordada ?? s.tarifaSugerida).toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Método de pago acordado con el cliente', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeConductorScreen(sesion: widget.sesion)), (route) => false);
              },
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pantallaCancelado() {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicio cancelado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, color: Colors.red, size: 72),
              const SizedBox(height: 16),
              const Text('El cliente canceló el servicio.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Se aplicó un recargo de \$0.40 al cliente para su próximo viaje.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeConductorScreen(sesion: widget.sesion)), (route) => false);
                },
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
