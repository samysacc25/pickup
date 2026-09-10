import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/go_pickup_theme.dart';
import '../../models/usuario.dart';
import '../../models/solicitud.dart';
import '../../models/oferta.dart';
import '../../services/auth_service.dart';
import '../../services/solicitud_service.dart';
import '../../services/solicitud_hub_service.dart';
import '../../services/conductor_service.dart' as conductor_srv;
import '../../services/push_notification_service.dart';
import '../../services/sonido_notificacion.dart';
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
  BitmapDescriptor? _iconoCamioneta;
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

  // Precios que este conductor ya ofertó, por solicitud: mientras la oferta
  // sigue pendiente, la tarjeta se queda mostrando "esperando respuesta" en
  // vez de desaparecer con el contador.
  final Map<int, Oferta> _ofertasEnviadas = {};
  StreamSubscription<Solicitud>? _subOfertaAceptada;
  StreamSubscription<int>? _subOfertaRechazada;

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
    _cargarIconoCamioneta();
    _obtenerUbicacionActual();
    _restaurarDisponibilidadSiCorresponde();
    _escucharRespuestasAOfertas();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService().inicializar(token: widget.sesion.token, context: context);
    });
  }

  // Si el conductor cerró la app (o Android la mató en segundo plano) sin
  // apagar manualmente la disponibilidad, el servidor lo sigue considerando
  // "Disponible". Antes, al reabrir la app, el switch siempre arrancaba en
  // Desconectado y dejaba de recibir solicitudes hasta que lo tocara de
  // nuevo. Ahora se consulta el estado real al abrir y, si sigue disponible,
  // se reconecta solo -- sigue "corriendo" hasta que el conductor apague la
  // disponibilidad él mismo.
  Future<void> _restaurarDisponibilidadSiCorresponde() async {
    final estado = await _conductorService.obtenerEstadoActual();
    if (!mounted) return;

    // El conductor quedó marcado como "en viaje" en el servidor: eso pasa,
    // por ejemplo, si el cliente aceptó el precio que él ofertó mientras la
    // app estaba cerrada. Antes se quedaba trabado -- el servidor no le
    // dejaba ofertar ni aceptar nada ("ya tienes un viaje en curso") y la
    // app no le mostraba ese viaje por ningún lado. Ahora se recupera y se
    // abre la pantalla del servicio que tiene pendiente.
    if (estado == conductor_srv.EstadoConductor.enViaje) {
      await _retomarViajeActivo();
      return;
    }

    if (estado == conductor_srv.EstadoConductor.disponible && !_disponible) {
      await _alternarDisponibilidad(true);
    }
  }

  Future<void> _retomarViajeActivo() async {
    try {
      final misViajes = await _solicitudService.misSolicitudes();
      if (!mounted) return;

      Solicitud? activo;
      for (final s in misViajes) {
        if (s.estaActiva) {
          activo = s;
          break;
        }
      }

      if (activo != null) {
        await _irAlViaje(activo.id);
        // Al terminar (o cancelarse) ese viaje el servidor lo deja
        // disponible otra vez: hay que reconectarlo aquí, si no la app se
        // queda mostrándolo como desconectado y no le entra ni una
        // solicitud hasta que toque el switch a mano.
        if (mounted) await _restaurarDisponibilidadSiCorresponde();
        return;
      }

      // Quedó marcado "en viaje" pero no hay ningún servicio activo (por
      // ejemplo si algo se cortó a medias): se libera para que pueda seguir
      // recibiendo solicitudes.
      await _conductorService.cambiarEstado(conductor_srv.EstadoConductor.disponible);
      if (mounted) await _alternarDisponibilidad(true);
    } catch (_) {}
  }

  Future<void> _cargarIconoCamioneta() async {
    try {
      final icono = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/icons/camioneta_marker.png',
      );
      if (mounted) setState(() => _iconoCamioneta = icono);
    } catch (_) {}
  }

  // Respuesta del cliente a un precio ofertado. Llega en vivo por el grupo
  // privado del conductor en SignalR; el sondeo de _revisarMisOfertas() es
  // el respaldo por si esa conexión se cayó.
  void _escucharRespuestasAOfertas() {
    _subOfertaAceptada = _hubService.ofertaAceptada.listen((solicitud) {
      if (!mounted) return;
      SonidoNotificacion.reproducir();
      _irAlViaje(solicitud.id);
    });

    _subOfertaRechazada = _hubService.ofertaRechazada.listen((solicitudId) {
      if (!mounted || _tieneViajeActivo) return;
      setState(() {
        _ofertasEnviadas.remove(solicitudId);
        _solicitudesEntrantes.removeWhere((s) => s.id == solicitudId);
      });
      mostrarError(context, 'El cliente no aceptó tu oferta.');
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

        // Se cancelan los anteriores por si esta ruta se recorre dos veces
        // (por ejemplo al volver de un viaje): si no, quedarían timers
        // duplicados reportando ubicación y consultando solicitudes.
        _timerUbicacion?.cancel();
        _timerSolicitudesDisponibles?.cancel();

        _timerUbicacion = Timer.periodic(const Duration(seconds: 10), (_) => _reportarUbicacion());
        _timerSolicitudesDisponibles = Timer.periodic(const Duration(seconds: 8), (_) {
          _revisarSolicitudesDisponibles();
          _revisarMisOfertas();
        });
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
    SonidoNotificacion.reproducir();
  }

  void _quitarSolicitudEntrante(int solicitudId) {
    if (!mounted) return;
    setState(() => _solicitudesEntrantes.removeWhere((s) => s.id == solicitudId));
  }

  Future<void> _aceptarSolicitudEntrante(Solicitud solicitud) async {
    try {
      final actualizada = await _solicitudService.aceptarSolicitud(solicitud.id);
      if (!mounted) return;
      await _irAlViaje(actualizada.id);
    } catch (e) {
      if (mounted) {
        _quitarSolicitudEntrante(solicitud.id);
        mostrarError(context, textoError(e));
      }
    }
  }

  // Entra a la pantalla del servicio. Se usa tanto al aceptar directo el
  // precio del cliente como cuando el cliente acepta un precio ofertado.
  Future<void> _irAlViaje(int solicitudId) async {
    if (_tieneViajeActivo) return;

    // Ya tiene viaje: se quitan las demás solicitudes pendientes y se deja
    // de mostrar nuevas mientras dure este servicio.
    setState(() {
      _tieneViajeActivo = true;
      _solicitudesEntrantes.clear();
      _ofertasEnviadas.clear();
    });

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServicioEnCursoConductorScreen(sesion: widget.sesion, solicitudId: solicitudId)),
    );
    if (mounted) setState(() => _tieneViajeActivo = false);
  }

  // Negociación de precio: en vez de aceptar el monto que puso el cliente,
  // el conductor propone el suyo y el cliente decide si lo acepta.
  Future<void> _ofertarPrecio(Solicitud solicitud) async {
    final sugerido = solicitud.tarifaPropuestaCliente ?? solicitud.tarifaSugerida;
    final controlador = TextEditingController(text: sugerido.toStringAsFixed(2));

    final monto = await showDialog<double>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Ofertar tu precio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'El cliente pide este viaje por \$${sugerido.toStringAsFixed(2)}. Puedes proponerle otro precio y él decide si lo acepta.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controlador,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Tu precio', prefixText: '\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final valor = double.tryParse(controlador.text.trim().replaceAll(',', '.'));
              if (valor == null || valor <= 0) return;
              Navigator.of(contexto).pop(valor);
            },
            child: const Text('Enviar oferta'),
          ),
        ],
      ),
    );

    controlador.dispose();
    if (monto == null || !mounted) return;

    try {
      final oferta = await _solicitudService.crearOferta(
        solicitud.id,
        monto,
        latitud: _posicionActual?.latitude,
        longitud: _posicionActual?.longitude,
      );
      if (!mounted) return;
      setState(() => _ofertasEnviadas[solicitud.id] = oferta);
      mostrarExito(context, 'Oferta enviada. Espera la respuesta del cliente.');
    } catch (e) {
      if (mounted) mostrarError(context, textoError(e));
    }
  }

  // Respaldo del aviso en tiempo real: revisa en qué quedaron las ofertas
  // que este conductor envió.
  Future<void> _revisarMisOfertas() async {
    if (_ofertasEnviadas.isEmpty || _tieneViajeActivo) return;

    try {
      final ofertas = await _solicitudService.misOfertas();
      if (!mounted) return;

      for (final oferta in ofertas) {
        if (!_ofertasEnviadas.containsKey(oferta.solicitudId)) continue;

        if (oferta.estado == EstadoOferta.aceptada) {
          SonidoNotificacion.reproducir();
          await _irAlViaje(oferta.solicitudId);
          return;
        }

        if (oferta.estado == EstadoOferta.rechazada) {
          setState(() {
            _ofertasEnviadas.remove(oferta.solicitudId);
            _solicitudesEntrantes.removeWhere((s) => s.id == oferta.solicitudId);
          });
        }
      }
    } catch (_) {}
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
    _subOfertaAceptada?.cancel();
    _subOfertaRechazada?.cancel();
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
            // Ícono de camioneta en la posición exacta del conductor.
            markers: _posicionActual == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('yo'),
                      position: LatLng(_posicionActual!.latitude, _posicionActual!.longitude),
                      infoWindow: const InfoWindow(title: 'Tu camioneta'),
                      icon: _iconoCamioneta ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
                      anchor: const Offset(0.5, 0.5),
                    )
                  },
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
                                montoOfertado: _ofertasEnviadas[s.id]?.monto,
                                onExpirar: () => _quitarSolicitudEntrante(s.id),
                                onRechazar: () => _quitarSolicitudEntrante(s.id),
                                onAceptar: () => _aceptarSolicitudEntrante(s),
                                onOfertar: () => _ofertarPrecio(s),
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

  // Devuelve un Future porque abre un diálogo: mientras el conductor decide
  // el precio, la tarjeta congela su contador para no desaparecerle debajo.
  final Future<void> Function() onOfertar;

  // Monto que este conductor ya ofertó para esta solicitud (si ofertó). Con
  // una oferta enviada la tarjeta deja de contar hacia atrás y se queda
  // esperando la respuesta del cliente.
  final double? montoOfertado;

  const _TarjetaSolicitudEntrante({
    super.key,
    required this.solicitud,
    required this.onAceptar,
    required this.onRechazar,
    required this.onExpirar,
    required this.onOfertar,
    this.montoOfertado,
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
    if (widget.montoOfertado == null) _iniciarContador();
  }

  void _iniciarContador() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundosRestantes <= 1) {
        t.cancel();
        if (!_procesando) widget.onExpirar();
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  // Mientras el diálogo del precio está abierto se detiene el contador: si
  // no, la tarjeta expiraba y desaparecía justo mientras el conductor
  // escribía su oferta. Si al final no ofertó, el contador se reanuda.
  Future<void> _abrirOferta() async {
    _timer?.cancel();
    _timer = null;
    // Además de congelar el contador, se bloquean los botones para que un
    // doble toque no abra dos diálogos (y mande dos ofertas).
    setState(() => _procesando = true);

    await widget.onOfertar();

    if (!mounted) return;
    setState(() => _procesando = false);
    if (widget.montoOfertado == null && _timer == null) _iniciarContador();
  }

  @override
  void didUpdateWidget(covariant _TarjetaSolicitudEntrante anterior) {
    super.didUpdateWidget(anterior);
    // Al enviar una oferta, la tarjeta ya no expira sola: se queda visible
    // mientras el cliente decide.
    if (widget.montoOfertado != null && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
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
    final yaOferto = widget.montoOfertado != null;

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
                if (!yaOferto) Text('$_segundosRestantes s', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
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
            if (!yaOferto)
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
            // Con una oferta ya enviada, la tarjeta solo espera la respuesta
            // del cliente (que llega en vivo o por el sondeo de mis-ofertas).
            if (yaOferto)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: GoPickupColors.verde.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GoPickupColors.verde),
                ),
                child: Row(
                  children: [
                    const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: GoPickupColors.verde)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ofertaste \$${widget.montoOfertado!.toStringAsFixed(2)} · esperando respuesta del cliente',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GoPickupColors.verdeOscuro),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
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
                    child: OutlinedButton(
                      onPressed: _procesando ? null : _abrirOferta,
                      child: const Text('Ofertar precio', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _procesando ? null : () { setState(() => _procesando = true); widget.onAceptar(); },
                style: ElevatedButton.styleFrom(backgroundColor: GoPickupColors.verde),
                child: _procesando
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Aceptar por \$${tarifa.toStringAsFixed(2)}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
