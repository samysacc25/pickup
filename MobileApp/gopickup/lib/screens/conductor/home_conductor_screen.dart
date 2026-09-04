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

  // Al conductor le pueden llegar varias solicitudes al mismo tiempo (por
  // ejemplo dos clientes pidiendo un viaje casi a la vez). Antes solo se
  // mostraba un diálogo bloqueante para la primera y las demás se perdían en
  // silencio mientras ese diálogo seguía abierto. Ahora se muestran todas
  // como tarjetas apiladas, cada una con su propio contador y sus propios
  // botones de Aceptar/Rechazar.
  final List<Solicitud> _solicitudesEntrantes = [];

  // Una vez que el conductor acepta un viaje, no debe seguir recibiendo
  // ofertas nuevas mientras esa pantalla de Home (que sigue viva debajo de
  // la pantalla del servicio en curso) siga escuchando en segundo plano.
  bool _tieneViajeActivo = false;

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
    if (!mounted || _tieneViajeActivo) return;
    if (_solicitudesEntrantes.any((s) => s.id == solicitud.id)) return;
    setState(() => _solicitudesEntrantes.add(solicitud));
  }

  void _quitarSolicitudEntrante(int solicitudId) {
    if (!mounted) return;
    setState(() => _solicitudesEntrantes.removeWhere((s) => s.id == solicitudId));
  }

  Future<void> _aceptarSolicitudEntrante(Solicitud solicitud) async {
    try {
      final actualizada = await _solicitudService.aceptarSolicitud(solicitud.id);
      if (!mounted) return;
      // Ya aceptó un viaje: se quitan todas las demás ofertas pendientes y se
      // deja de mostrar nuevas mientras dure este servicio.
      setState(() {
        _tieneViajeActivo = true;
        _solicitudesEntrantes.clear();
      });
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ServicioEnCursoConductorScreen(sesion: widget.sesion, solicitudId: actualizada.id)),
      );
      if (mounted) setState(() => _tieneViajeActivo = false);
    } catch (e) {
      if (mounted) {
        _quitarSolicitudEntrante(solicitud.id);
        mostrarError(context, textoError(e));
      }
    }
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
    _hubService.dispose();
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
          if (_solicitudesEntrantes.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _solicitudesEntrantes
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TarjetaSolicitudEntrante(
                                key: ValueKey(s.id),
                                solicitud: s,
                                onExpirar: () => _quitarSolicitudEntrante(s.id),
                                onRechazar: () => _quitarSolicitudEntrante(s.id),
                                onAceptar: () => _aceptarSolicitudEntrante(s),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
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

// Tarjeta compacta y apilable para una solicitud entrante. A diferencia del
// diálogo anterior, varias de estas pueden mostrarse al mismo tiempo (una
// debajo de otra) cuando llegan varias solicitudes juntas -- cada una con su
// propio contador regresivo y sus propios botones.
class _TarjetaSolicitudEntrante extends StatefulWidget {
  final Solicitud solicitud;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
  final VoidCallback onExpirar;

  const _TarjetaSolicitudEntrante({
    super.key,
    required this.solicitud,
    required this.onAceptar,
    required this.onRechazar,
    required this.onExpirar,
  });

  @override
  State<_TarjetaSolicitudEntrante> createState() => _TarjetaSolicitudEntranteState();
}

class _TarjetaSolicitudEntranteState extends State<_TarjetaSolicitudEntrante> {
  static const int _segundosTotales = 25;
  int _segundosRestantes = _segundosTotales;
  Timer? _timer;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundosRestantes <= 1) {
        t.cancel();
        if (!_procesando) widget.onExpirar();
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
    final progreso = _segundosRestantes / _segundosTotales;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('\$${tarifa.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: GoPickupColors.verdeOscuro)),
                const SizedBox(width: 8),
                Text('$_segundosRestantes s', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (s.distanciaKm != null)
                  Chip(
                    label: Text('${s.distanciaKm!.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 4,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(progreso > 0.3 ? GoPickupColors.verde : Colors.red),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const CircleAvatar(radius: 16, backgroundColor: GoPickupColors.verde, child: Icon(Icons.person, color: Colors.white, size: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        s.llevaCarga ? (s.descripcionCarga ?? 'Con carga adicional') : 'Solo pasajero',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.circle, size: 9, color: GoPickupColors.verde),
              const SizedBox(width: 6),
              Expanded(child: Text(s.origenDireccion, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on, size: 13, color: Colors.red),
              const SizedBox(width: 6),
              Expanded(child: Text(s.destinoDireccion, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _procesando ? null : () { setState(() => _procesando = true); widget.onRechazar(); },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _procesando ? null : () { setState(() => _procesando = true); widget.onAceptar(); },
                    style: ElevatedButton.styleFrom(backgroundColor: GoPickupColors.verde),
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
    );
  }
}
