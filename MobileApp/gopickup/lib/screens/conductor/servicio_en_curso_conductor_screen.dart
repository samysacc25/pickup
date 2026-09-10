import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/go_pickup_theme.dart';
import '../../models/usuario.dart';
import '../../models/solicitud.dart';
import '../../services/solicitud_service.dart';
import '../../services/solicitud_hub_service.dart';
import '../../services/rutas_service.dart';
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

  // Ubicación propia del conductor, para dibujar su camioneta en el mapa y
  // calcular desde ahí la ruta hasta el siguiente punto.
  LatLng? _miUbicacion;
  BitmapDescriptor? _iconoCamioneta;

  // Mantiene la mejor ruta actualizada sin consultar la Directions API en
  // cada actualización del GPS (ver SeguidorRuta).
  final _seguidorRuta = SeguidorRuta();
  GoogleMapController? _mapController;

  // Recuerda para qué etapa del viaje ya se encuadró el mapa, para no estar
  // moviéndole la cámara al conductor cada vez que se recalcula la ruta.
  EstadoSolicitud? _etapaEncuadrada;
  bool _encuadrando = false;

  @override
  void initState() {
    super.initState();
    _solicitudService = SolicitudService(widget.sesion.token);
    _conductorService = conductor_srv.ConductorService(widget.sesion.token);
    _hubService = SolicitudHubService(widget.sesion.token);
    _cargarIconoCamioneta();
    _cargar();
    _hubService.conectarYUnirse(
      solicitudId: widget.solicitudId,
      alActualizarSolicitud: (s) {
        if (mounted) setState(() => _solicitud = s);
      },
      alActualizarUbicacion: (_, __) {},
    );
    // La primera lectura del GPS se pide de inmediato para que la ruta y la
    // camioneta aparezcan al abrir la pantalla, no a los 8 segundos.
    _reportarUbicacion();
    _timerUbicacion = Timer.periodic(const Duration(seconds: 8), (_) => _reportarUbicacion());
  }

  Future<void> _cargarIconoCamioneta() async {
    try {
      final icono = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/icons/camioneta_marker.png',
      );
      if (mounted) setState(() => _iconoCamioneta = icono);
    } catch (_) {
      // Si el asset no carga, se usa el marcador por defecto.
    }
  }

  Future<void> _cargar() async {
    try {
      final s = await _solicitudService.obtenerSolicitud(widget.solicitudId);
      if (mounted) setState(() => _solicitud = s);
      _actualizarRuta();
    } catch (e) {
      if (mounted) mostrarError(context, textoError(e));
    }
  }

  Future<void> _reportarUbicacion() async {
    try {
      final posicion = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _miUbicacion = LatLng(posicion.latitude, posicion.longitude));
      await _conductorService.actualizarUbicacion(posicion.latitude, posicion.longitude);
      await _hubService.enviarUbicacion(widget.solicitudId, posicion.latitude, posicion.longitude);
      await _actualizarRuta();
    } catch (_) {}
  }

  // Punto al que el conductor tiene que llegar ahora mismo: el de recogida
  // mientras va por el cliente, y el destino final una vez iniciado el viaje.
  LatLng? get _destinoActual {
    final s = _solicitud;
    if (s == null) return null;
    return s.estado == EstadoSolicitud.iniciada
        ? LatLng(s.destinoLatitud, s.destinoLongitud)
        : LatLng(s.origenLatitud, s.origenLongitud);
  }

  Future<void> _actualizarRuta() async {
    final origen = _miUbicacion;
    final destino = _destinoActual;
    if (origen == null || destino == null) return;

    final cambio = await _seguidorRuta.actualizar(origen: origen, destino: destino);
    if (!cambio || !mounted) return;

    setState(() {});
    _encuadrarSiHaceFalta();
  }

  void _encuadrarSiHaceFalta() {
    final ruta = _seguidorRuta.ruta;
    final estado = _solicitud?.estado;
    final controlador = _mapController;
    if (ruta == null || estado == null || controlador == null) return;
    if (_etapaEncuadrada == estado || _encuadrando) return;

    _encuadrando = true;

    // Cuando esto se dispara desde onMapCreated el mapa todavía no tiene
    // tamaño en pantalla, y encuadrar en ese momento revienta con
    // "Map size can't be 0". Por eso se espera al primer frame ya dibujado
    // y, si aun así falla, se deja la cámara como está en vez de tumbar la
    // pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await controlador.animateCamera(CameraUpdate.newLatLngBounds(_limitesDe(ruta.puntos), 70));
        _etapaEncuadrada = estado;
      } catch (_) {
        // Se reintenta en la siguiente actualización de la ruta.
      } finally {
        _encuadrando = false;
      }
    });
  }

  LatLngBounds _limitesDe(List<LatLng> puntos) {
    var surOeste = puntos.first;
    var norEste = puntos.first;

    for (final p in puntos) {
      surOeste = LatLng(
        p.latitude < surOeste.latitude ? p.latitude : surOeste.latitude,
        p.longitude < surOeste.longitude ? p.longitude : surOeste.longitude,
      );
      norEste = LatLng(
        p.latitude > norEste.latitude ? p.latitude : norEste.latitude,
        p.longitude > norEste.longitude ? p.longitude : norEste.longitude,
      );
    }

    return LatLngBounds(southwest: surOeste, northeast: norEste);
  }

  // Abre la navegación paso a paso de Google Maps hacia el punto que toca
  // ahora. La ruta del mapa de la app sirve para ubicarse de un vistazo;
  // para manejar es más seguro usar la navegación por voz de Google Maps.
  Future<void> _abrirNavegacion() async {
    final destino = _destinoActual;
    if (destino == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${destino.latitude},${destino.longitude}'
      '&travelmode=driving&dir_action=navigate',
    );

    try {
      final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abierto && mounted) mostrarError(context, 'No se pudo abrir Google Maps.');
    } catch (_) {
      if (mounted) mostrarError(context, 'No se pudo abrir Google Maps.');
    }
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
      // Al iniciar el viaje el destino de la ruta cambia (del punto de
      // recogida al destino final): se recalcula enseguida en vez de
      // esperar la siguiente lectura del GPS.
      _actualizarRuta();
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

    final ruta = _seguidorRuta.ruta;
    final vaAlDestino = s.estado == EstadoSolicitud.iniciada;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicio en curso'),
        actions: [IconButton(icon: const Icon(Icons.chat_bubble_outline), tooltip: 'Chat con el cliente', onPressed: _abrirChat)],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: LatLng(s.origenLatitud, s.origenLongitud), zoom: 14),
                  onMapCreated: (c) {
                    _mapController = c;
                    _encuadrarSiHaceFalta();
                  },
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
                    // La camioneta del propio conductor, en su posición exacta.
                    if (_miUbicacion != null)
                      Marker(
                        markerId: const MarkerId('mi_camioneta'),
                        position: _miUbicacion!,
                        infoWindow: const InfoWindow(title: 'Tú'),
                        icon: _iconoCamioneta ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
                        anchor: const Offset(0.5, 0.5),
                      ),
                  },
                  // La mejor ruta por calles hasta el punto que toca ahora.
                  polylines: ruta == null
                      ? {}
                      : {
                          Polyline(
                            polylineId: const PolylineId('ruta'),
                            points: ruta.puntos,
                            color: vaAlDestino ? GoPickupColors.verdeOscuro : GoPickupColors.verde,
                            width: 5,
                          ),
                        },
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.extended(
                    heroTag: 'navegar',
                    backgroundColor: Colors.white,
                    foregroundColor: GoPickupColors.verdeOscuro,
                    onPressed: _abrirNavegacion,
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Navegar'),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(textoEstado(s.estado), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GoPickupColors.verdeOscuro)),
                if (ruta != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 15, color: GoPickupColors.verde),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vaAlDestino
                              ? 'Al destino: ~${ruta.minutos} min · ${ruta.distanciaKm.toStringAsFixed(1)} km'
                              : 'Al punto de recogida: ~${ruta.minutos} min · ${ruta.distanciaKm.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GoPickupColors.verde),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(child: Text(s.clienteNombre, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(icon: const Icon(Icons.chat_bubble_outline, color: GoPickupColors.verde), onPressed: _abrirChat),
                  if (s.clienteTelefono != null)
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: () => llamarA(context, s.clienteTelefono),
                    ),
                ]),
                if (s.clienteCedula != null && s.clienteCedula!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.badge_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('Cédula: ${s.clienteCedula}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                ],
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
