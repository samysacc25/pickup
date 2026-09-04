import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/go_pickup_theme.dart';
import '../../models/usuario.dart';
import '../../models/solicitud.dart';
import '../../services/auth_service.dart';
import '../../services/solicitud_service.dart';
import '../../services/solicitud_hub_service.dart';
import '../../services/conductor_service.dart' as conductor_srv;
import '../../services/push_notification_service.dart';
import '../../theme/responsive.dart';
import '../../widgets/notificacion.dart';
import '../login_screen.dart';
import 'servicio_en_curso_conductor_screen.dart';

class HomeConductorScreen extends StatefulWidget {
  final SesionUsuario sesion;
  const HomeConductorScreen({super.key, required this.sesion});

  @override
  State<HomeConductorScreen> createState() => _HomeConductorScreenState();
}

class _HomeConductorScreenState extends State<HomeConductorScreen> {
  late final SolicitudService _solicitudService;
  late final conductor_srv.ConductorService _conductorService;
  late final SolicitudHubService _hubService;

  GoogleMapController? _mapController;
  Position? _posicionActual;
  Timer? _timerUbicacion;
  Timer? _timerSolicitudesDisponibles;
  final Set<int> _solicitudesYaMostradas = {};

  bool _disponible = false;
  bool _cambiandoDisponibilidad = false;
  bool _dialogoAbierto = false;

  static const CameraPosition _posicionInicial = CameraPosition(
    target: LatLng(-1.2417, -78.6197),
    zoom: 13,
  );

  @override
  void initState() {
    super.initState();
    _solicitudService = SolicitudService(widget.sesion.token);
    _conductorService = conductor_srv.ConductorService(widget.sesion.token);
    _hubService = SolicitudHubService(widget.sesion.token);
    _obtenerUbicacionActual();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService().inicializar(token: widget.sesion.token, context: context);
    });
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();

      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (!servicioActivo) return;

      final posicion = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _posicionActual = posicion);
      _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(posicion.latitude, posicion.longitude)));
    } catch (_) {}
  }

  Future<void> _alternarDisponibilidad(bool activar) async {
    setState(() => _cambiandoDisponibilidad = true);

    try {
      if (activar) {
        await _conductorService.cambiarEstado(conductor_srv.EstadoConductor.disponible);

        try {
          await _hubService
              .conectarComoConductorDisponible(alLlegarNuevaSolicitud: _mostrarSolicitudEntrante)
              .timeout(const Duration(seconds: 12));
        } catch (_) {
          if (mounted) {
            mostrarError(context, 'El aviso en tiempo real no está disponible ahora mismo; seguirás recibiendo solicitudes cada pocos segundos.');
          }
        }

        _timerUbicacion = Timer.periodic(const Duration(seconds: 10), (_) => _reportarUbicacion());
        _timerSolicitudesDisponibles = Timer.periodic(const Duration(seconds: 8), (_) => _revisarSolicitudesDisponibles());
        _reportarUbicacion();
        _revisarSolicitudesDisponibles();
      } else {
        await _conductorService.cambiarEstado(conductor_srv.EstadoConductor.desconectado);
        await _hubService.desconectar().timeout(const Duration(seconds: 5), onTimeout: () {});
        _timerUbicacion?.cancel();
        _timerSolicitudesDisponibles?.cancel();
      }

      if (mounted) setState(() => _disponible = activar);
    } catch (e) {
      if (mounted) mostrarError(context, textoError(e));
    } finally {
      if (mounted) setState(() => _cambiandoDisponibilidad = false);
    }
  }

  Future<void> _revisarSolicitudesDisponibles() async {
    if (!_disponible && !_cambiandoDisponibilidad) return;
    try {
      final disponibles = await _solicitudService.solicitudesDisponibles();
      for (final s in disponibles) {
        if (!_solicitudesYaMostradas.contains(s.id)) {
          _solicitudesYaMostradas.add(s.id);
          _mostrarSolicitudEntrante(s);
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _reportarUbicacion() async {
    try {
      final posicion = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _posicionActual = posicion);
      await _conductorService.actualizarUbicacion(posicion.latitude, posicion.longitude);
    } catch (_) {}
  }

  void _mostrarSolicitudEntrante(Solicitud solicitud) {
    if (_dialogoAbierto || !mounted) return;
    _dialogoAbierto = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DialogoNuevaSolicitud(
        solicitud: solicitud,
        onRechazar: () {
          _dialogoAbierto = false;
          Navigator.of(context).pop();
        },
        onAceptar: () async {
          try {
            final actualizada = await _solicitudService.aceptarSolicitud(solicitud.id);
            _dialogoAbierto = false;
            if (mounted) Navigator.of(context).pop();
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ServicioEnCursoConductorScreen(sesion: widget.sesion, solicitudId: actualizada.id)),
              );
            }
          } catch (e) {
            _dialogoAbierto = false;
            if (mounted) Navigator.of(context).pop();
            if (mounted) mostrarError(context, textoError(e));
          }
        },
      ),
    ).then((_) => _dialogoAbierto = false);
  }

  Future<void> _cerrarSesion() async {
    await _hubService.desconectar();
    _timerUbicacion?.cancel();
    _timerSolicitudesDisponibles?.cancel();
    await AuthService().cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  void dispose() {
    _timerUbicacion?.cancel();
    _timerSolicitudesDisponibles?.cancel();
    _hubService.desconectar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.sesion.nombreCompleto.split(' ').first}'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _cerrarSesion)],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _posicionInicial,
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _posicionActual == null
                ? {}
                : {Marker(markerId: const MarkerId('yo'), position: LatLng(_posicionActual!.latitude, _posicionActual!.longitude))},
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: EdgeInsets.all(context.responsive.esTablet ? 32 : 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)]),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: _disponible ? GoPickupColors.verde : Colors.grey)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_disponible ? 'Disponible · esperando solicitudes...' : 'Desconectado', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    _cambiandoDisponibilidad
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Switch(value: _disponible, activeColor: GoPickupColors.verde, onChanged: _alternarDisponibilidad),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogoNuevaSolicitud extends StatefulWidget {
  final Solicitud solicitud;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const _DialogoNuevaSolicitud({required this.solicitud, required this.onAceptar, required this.onRechazar});

  @override
  State<_DialogoNuevaSolicitud> createState() => _DialogoNuevaSolicitudState();
}

class _DialogoNuevaSolicitudState extends State<_DialogoNuevaSolicitud> {
  int _segundosRestantes = 25;
  Timer? _timer;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundosRestantes <= 1) {
        t.cancel();
        if (!_procesando) widget.onRechazar();
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final tarifa = s.tarifaPropuestaCliente ?? s.tarifaSugerida;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping, color: GoPickupColors.verde, size: 28),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('¡Nueva solicitud!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  Text('$_segundosRestantes s', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.circle, size: 10, color: GoPickupColors.verde),
                const SizedBox(width: 8),
                Expanded(child: Text(s.origenDireccion, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on, size: 14, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(child: Text(s.destinoDireccion, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(s.llevaCarga ? 'Con carga adicional' : 'Solo pasajero')),
                  if (s.distanciaKm != null) Chip(label: Text('${s.distanciaKm!.toStringAsFixed(1)} km')),
                ],
              ),
              const SizedBox(height: 14),
              Text('\$${tarifa.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: GoPickupColors.verdeOscuro)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _procesando ? null : () { setState(() => _procesando = true); widget.onRechazar(); },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _procesando ? null : () { setState(() => _procesando = true); widget.onAceptar(); },
                      child: _procesando
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Aceptar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
