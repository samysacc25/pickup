import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/go_pickup_theme.dart';
import '../../models/usuario.dart';
import '../../models/solicitud.dart';
import '../../models/oferta.dart';
import '../../services/solicitud_service.dart';
import '../../services/solicitud_hub_service.dart';
import '../../services/calculadora_eta.dart';
import '../../services/rutas_service.dart';
import '../../services/sonido_notificacion.dart';
import '../../widgets/notificacion.dart';
import '../shared/chat_screen.dart';
import 'home_cliente_screen.dart';

class SolicitudEnCursoScreen extends StatefulWidget {
  final SesionUsuario sesion;
  final int solicitudId;

  const SolicitudEnCursoScreen({super.key, required this.sesion, required this.solicitudId});

  @override
  State<SolicitudEnCursoScreen> createState() => _SolicitudEnCursoScreenState();
}

class _SolicitudEnCursoScreenState extends State<SolicitudEnCursoScreen> {
  late final SolicitudService _solicitudService;
  late final SolicitudHubService _hubService;
  Timer? _timerRespaldo;
  StreamSubscription<void>? _subConductorLlego;
  StreamSubscription<Oferta>? _subNuevaOferta;

  BitmapDescriptor? _iconoCamioneta;
  Solicitud? _solicitud;
  LatLng? _ubicacionConductor;
  int? _minutosEta;
  bool _cancelando = false;

  // Ofertas de precio que han hecho los conductores mientras la solicitud
  // sigue buscando: el cliente elige cuál acepta.
  List<Oferta> _ofertas = [];
  bool _procesandoOferta = false;

  // Ofertas que el cliente ya resolvió en esta pantalla (aceptó o rechazó).
  // Sin esto, una consulta de respaldo que venía en camino podía volver a
  // pintar en la lista una oferta ya rechazada y dejarlo pulsarla de nuevo.
  final Set<int> _ofertasResueltas = {};

  // Ruta real por calles, para que el cliente vea el trayecto y un tiempo
  // de llegada que tiene en cuenta las calles y el tráfico.
  final _seguidorRuta = SeguidorRuta();
  GoogleMapController? _mapController;
  EstadoSolicitud? _etapaEncuadrada;
  bool _encuadrando = false;

  @override
  void initState() {
    super.initState();
    _solicitudService = SolicitudService(widget.sesion.token);
    _hubService = SolicitudHubService(widget.sesion.token);
    _cargarIconoCamioneta();
    _cargarSolicitud();
    _cargarOfertas();
    _conectarTiempoReal();
    _subConductorLlego = _hubService.conductorLlego.listen((_) {
      if (!mounted) return;
      SonidoNotificacion.reproducir();
      mostrarExito(context, 'Tu conductor ya llegó al punto de recogida.');
    });
    _subNuevaOferta = _hubService.nuevasOfertas.listen((oferta) {
      if (!mounted) return;
      // Si el viaje ya dejó de buscar conductor (o el cliente ya resolvió
      // esa oferta), no tiene sentido volver a mostrarla.
      if (_solicitud != null && _solicitud!.estado != EstadoSolicitud.buscando) return;
      if (_ofertasResueltas.contains(oferta.id)) return;

      SonidoNotificacion.reproducir();
      setState(() {
        _ofertas = [..._ofertas.where((o) => o.id != oferta.id && o.conductorId != oferta.conductorId), oferta]
          ..sort((a, b) => a.monto.compareTo(b.monto));
      });
    });
    _timerRespaldo = Timer.periodic(const Duration(seconds: 8), (_) {
      _cargarSolicitud();
      _cargarOfertas();
    });
  }

  Future<void> _cargarIconoCamioneta() async {
    try {
      final icono = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/icons/camioneta_marker.png',
      );
      if (mounted) setState(() => _iconoCamioneta = icono);
    } catch (_) {
      // Si el asset no carga por algún motivo, usamos el marcador amarillo por defecto.
    }
  }

  Future<void> _cargarSolicitud() async {
    try {
      final solicitud = await _solicitudService.obtenerSolicitud(widget.solicitudId);
      if (!mounted) return;
      setState(() {
        _solicitud = solicitud;
        if (solicitud.conductorLatitud != null && solicitud.conductorLongitud != null) {
          _ubicacionConductor = LatLng(solicitud.conductorLatitud!, solicitud.conductorLongitud!);
          _recalcularEta();
        }
      });
      _actualizarRuta();
    } catch (_) {}
  }

  Future<void> _cargarOfertas() async {
    final estado = _solicitud?.estado;
    if (estado != null && estado != EstadoSolicitud.buscando) {
      if (_ofertas.isNotEmpty && mounted) setState(() => _ofertas = []);
      return;
    }

    try {
      final ofertas = await _solicitudService.obtenerOfertas(widget.solicitudId);
      if (!mounted) return;

      // El estado pudo cambiar mientras esta consulta iba y venía (el
      // cliente aceptó una oferta, el viaje arrancó...): se descarta la
      // respuesta vieja en vez de repintar ofertas que ya no aplican.
      if (_solicitud != null && _solicitud!.estado != EstadoSolicitud.buscando) return;

      final vigentes = ofertas.where((o) => !_ofertasResueltas.contains(o.id)).toList()
        ..sort((a, b) => a.monto.compareTo(b.monto));
      setState(() => _ofertas = vigentes);
    } catch (_) {}
  }

  // Estimación inmediata en línea recta; en cuanto responde la Directions
  // API se reemplaza por el tiempo real de la ruta (ver _actualizarRuta).
  void _recalcularEta() {
    if (_ubicacionConductor == null || _solicitud == null) return;

    final destinoCalculo = _solicitud!.estado == EstadoSolicitud.iniciada
        ? LatLng(_solicitud!.destinoLatitud, _solicitud!.destinoLongitud)
        : LatLng(_solicitud!.origenLatitud, _solicitud!.origenLongitud);

    _minutosEta = CalculadoraEta.minutosEstimados(
      _ubicacionConductor!.latitude,
      _ubicacionConductor!.longitude,
      destinoCalculo.latitude,
      destinoCalculo.longitude,
    );
  }

  Future<void> _actualizarRuta() async {
    final s = _solicitud;
    if (s == null) return;

    final puntoOrigen = LatLng(s.origenLatitud, s.origenLongitud);
    final puntoDestino = LatLng(s.destinoLatitud, s.destinoLongitud);

    LatLng origen;
    LatLng destino;

    if (s.estado == EstadoSolicitud.buscando) {
      // Todavía sin conductor: se dibuja el trayecto del viaje.
      origen = puntoOrigen;
      destino = puntoDestino;
    } else if (s.estado == EstadoSolicitud.iniciada) {
      // Ya a bordo: del punto donde va la camioneta hacia el destino.
      origen = _ubicacionConductor ?? puntoOrigen;
      destino = puntoDestino;
    } else {
      // El conductor viene por el cliente.
      if (_ubicacionConductor == null) return;
      origen = _ubicacionConductor!;
      destino = puntoOrigen;
    }

    final cambio = await _seguidorRuta.actualizar(origen: origen, destino: destino);
    if (!cambio || !mounted) return;

    setState(() {
      if (s.estado != EstadoSolicitud.buscando) _minutosEta = _seguidorRuta.ruta?.minutos;
    });
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
    // y, si aun así falla, se deja la cámara como está.
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

  Future<void> _conectarTiempoReal() async {
    await _hubService.conectarYUnirse(
      solicitudId: widget.solicitudId,
      alActualizarSolicitud: (viaje) {
        if (!mounted) return;
        setState(() => _solicitud = viaje);
        _actualizarRuta();
      },
      alActualizarUbicacion: (lat, lng) {
        if (!mounted) return;
        setState(() {
          _ubicacionConductor = LatLng(lat, lng);
          _recalcularEta();
        });
        _actualizarRuta();
      },
    );
  }

  Future<void> _aceptarOferta(Oferta oferta) async {
    setState(() {
      _procesandoOferta = true;
      _ofertasResueltas.add(oferta.id);
    });
    try {
      final actualizada = await _solicitudService.aceptarOferta(widget.solicitudId, oferta.id);
      if (!mounted) return;
      setState(() {
        _solicitud = actualizada;
        _ofertas = [];
      });
      mostrarExito(context, 'Aceptaste el precio de ${oferta.conductorNombre}. Ya viene en camino.');
      _actualizarRuta();
    } catch (e) {
      if (mounted) {
        mostrarError(context, textoError(e));
        // No se pudo aceptar (por ejemplo, ese conductor ya tomó otro
        // viaje): la oferta vuelve a estar sin resolver y se refresca la
        // lista para que el cliente vea las que siguen vigentes.
        _ofertasResueltas.remove(oferta.id);
        await _cargarOfertas();
      }
    } finally {
      if (mounted) setState(() => _procesandoOferta = false);
    }
  }

  Future<void> _rechazarOferta(Oferta oferta) async {
    setState(() {
      _ofertasResueltas.add(oferta.id);
      _ofertas = _ofertas.where((o) => o.id != oferta.id).toList();
    });

    try {
      await _solicitudService.rechazarOferta(widget.solicitudId, oferta.id);
    } catch (_) {
      // Si el rechazo no llegó al servidor, la oferta sigue viva allá: se
      // vuelve a dar por no resuelta para que el sondeo la muestre de
      // nuevo, en vez de dejarla escondida para siempre con el conductor
      // esperando una respuesta que nunca le va a llegar.
      if (!mounted) return;
      _ofertasResueltas.remove(oferta.id);
      await _cargarOfertas();
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
          miRol: 'cliente',
          nombreOtraPersona: _solicitud!.conductorNombre ?? 'Tu conductor',
        ),
      ),
    );
  }

  Future<void> _cancelarSolicitud() async {
    setState(() => _cancelando = true);
    try {
      await _solicitudService.cancelarSolicitud(widget.solicitudId, motivo: 'Cancelado por el cliente');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeClienteScreen(sesion: widget.sesion)), (route) => false);
    } catch (e) {
      if (mounted) mostrarError(context, textoError(e));
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  void dispose() {
    _timerRespaldo?.cancel();
    _subConductorLlego?.cancel();
    _subNuevaOferta?.cancel();
    _hubService.desconectar();
    _hubService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final solicitud = _solicitud;
    if (solicitud == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (solicitud.estado == EstadoSolicitud.finalizada) return _pantallaFinalizada(solicitud);
    if (solicitud.estado == EstadoSolicitud.canceladaConductor || solicitud.estado == EstadoSolicitud.sinConductores) {
      return _pantallaCancelada(solicitud);
    }

    final tarifaMostrar = solicitud.tarifaAcordada ?? solicitud.tarifaPropuestaCliente ?? solicitud.tarifaSugerida;
    final tieneChatDisponible = solicitud.conductorNombre != null;
    final ruta = _seguidorRuta.ruta;
    final buscando = solicitud.estado == EstadoSolicitud.buscando;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu viaje'),
        actions: [
          if (tieneChatDisponible)
            IconButton(icon: const Icon(Icons.chat_bubble_outline), tooltip: 'Chat con el conductor', onPressed: _abrirChat),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(solicitud.origenLatitud, solicitud.origenLongitud), zoom: 14),
              onMapCreated: (c) {
                _mapController = c;
                _encuadrarSiHaceFalta();
              },
              markers: {
                Marker(
                  markerId: const MarkerId('origen'),
                  position: LatLng(solicitud.origenLatitud, solicitud.origenLongitud),
                  infoWindow: const InfoWindow(title: 'Punto de recogida'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
                Marker(
                  markerId: const MarkerId('destino'),
                  position: LatLng(solicitud.destinoLatitud, solicitud.destinoLongitud),
                  infoWindow: const InfoWindow(title: 'Destino'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
                if (_ubicacionConductor != null)
                  Marker(
                    markerId: const MarkerId('conductor'),
                    position: _ubicacionConductor!,
                    infoWindow: const InfoWindow(title: 'Tu camioneta'),
                    icon: _iconoCamioneta ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
                    anchor: const Offset(0.5, 0.5),
                  ),
              },
              polylines: ruta == null
                  ? {}
                  : {
                      Polyline(
                        polylineId: const PolylineId('ruta'),
                        points: ruta.puntos,
                        color: GoPickupColors.verde,
                        width: 5,
                      ),
                    },
            ),
          ),
          Container(
            // Con varias ofertas en pantalla este panel crece bastante: se
            // le pone un tope de altura y se hace desplazable para que no
            // se desborde en celulares de pantalla corta.
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)]),
            child: SingleChildScrollView(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(textoEstado(solicitud.estado), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GoPickupColors.verdeOscuro)),
                if (_minutosEta != null &&
                    (solicitud.estado == EstadoSolicitud.aceptada || solicitud.estado == EstadoSolicitud.enCamino || solicitud.estado == EstadoSolicitud.iniciada))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 15, color: GoPickupColors.verde),
                        const SizedBox(width: 4),
                        Text(textoEta(_minutosEta!), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GoPickupColors.verde)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                if (buscando) _seccionOfertas(solicitud),
                if (solicitud.conductorNombre != null) ...[
                  Row(
                    children: [
                      const CircleAvatar(backgroundColor: GoPickupColors.verde, child: Icon(Icons.local_shipping, color: Colors.white)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(solicitud.conductorNombre!, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${solicitud.vehiculoDescripcion ?? ''} · ${solicitud.vehiculoPlaca ?? ''}'),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.chat_bubble_outline, color: GoPickupColors.verde), onPressed: _abrirChat),
                      if (solicitud.conductorTelefono != null)
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () => llamarA(context, solicitud.conductorTelefono),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tarifa: \$${tarifaMostrar.toStringAsFixed(2)}'),
                    if (solicitud.distanciaKm != null) Text('${solicitud.distanciaKm!.toStringAsFixed(1)} km'),
                  ],
                ),
                if (solicitud.recargoAplicado != null && solicitud.recargoAplicado! > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Incluye recargo de \$${solicitud.recargoAplicado!.toStringAsFixed(2)} por cancelación anterior',
                      style: const TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                const SizedBox(height: 16),
                if (solicitud.estado == EstadoSolicitud.buscando || solicitud.estado == EstadoSolicitud.aceptada)
                  OutlinedButton(
                    onPressed: _cancelando ? null : _cancelarSolicitud,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: _cancelando ? const Text('Cancelando...') : const Text('Cancelar viaje'),
                  ),
                if (solicitud.estado == EstadoSolicitud.aceptada)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Si cancelas ahora que ya hay un conductor asignado, se te cobrará un recargo de \$0.40 en tu próximo viaje.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ofertas de precio recibidas mientras se busca conductor. El cliente ve
  // cuánto pide cada conductor, su calificación y en cuánto llegaría, y
  // decide cuál acepta.
  Widget _seccionOfertas(Solicitud solicitud) {
    if (_ofertas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Pediste este viaje por \$${(solicitud.tarifaPropuestaCliente ?? solicitud.tarifaSugerida).toStringAsFixed(2)}. '
          'Si algún conductor te propone otro precio, lo verás aquí para aceptarlo o rechazarlo.',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _ofertas.length == 1 ? 'Tienes 1 oferta' : 'Tienes ${_ofertas.length} ofertas',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          // Las tarjetas van como hijas normales de la columna (y no en una
          // lista con su propio scroll) porque el panel entero ya se
          // desplaza: así no se pelean dos scrolls en el mismo eje.
          ..._ofertas.map(
            (oferta) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TarjetaOferta(
                oferta: oferta,
                deshabilitado: _procesandoOferta,
                onAceptar: () => _aceptarOferta(oferta),
                onRechazar: () => _rechazarOferta(oferta),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pantallaFinalizada(Solicitud solicitud) {
    int calificacion = 5;
    final total = solicitud.tarifaFinal ?? solicitud.tarifaAcordada ?? solicitud.tarifaSugerida;
    return Scaffold(
      appBar: AppBar(title: const Text('Viaje finalizado')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: GoPickupColors.verde, size: 72),
            const SizedBox(height: 16),
            Text('Total: \$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Text('¿Cómo calificarías a tu conductor?'),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setEstado) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final valor = i + 1;
                  return IconButton(
                    icon: Icon(valor <= calificacion ? Icons.star : Icons.star_border, color: GoPickupColors.verde, size: 32),
                    onPressed: () => setEstado(() => calificacion = valor),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _solicitudService.calificarConductor(solicitud.id, calificacion);
                } catch (_) {}
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeClienteScreen(sesion: widget.sesion)), (route) => false);
              },
              child: const Text('Finalizar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pantallaCancelada(Solicitud solicitud) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viaje cancelado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, color: Colors.red, size: 72),
              const SizedBox(height: 16),
              Text(textoEstado(solicitud.estado), style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeClienteScreen(sesion: widget.sesion)), (route) => false);
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

class _TarjetaOferta extends StatelessWidget {
  final Oferta oferta;
  final bool deshabilitado;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const _TarjetaOferta({
    required this.oferta,
    required this.deshabilitado,
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 18, backgroundColor: GoPickupColors.verde, child: Icon(Icons.local_shipping, color: Colors.white, size: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(oferta.conductorNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(oferta.calificacionConductor.toStringAsFixed(1), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        if (oferta.minutosLlegadaEstimados != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.timer_outlined, size: 12, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text('~${oferta.minutosLlegadaEstimados} min', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text('\$${oferta.monto.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: GoPickupColors.verdeOscuro)),
            ],
          ),
          if (oferta.vehiculoDescripcion != null) ...[
            const SizedBox(height: 6),
            Text(
              '${oferta.vehiculoDescripcion} · ${oferta.vehiculoPlaca ?? ''}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: deshabilitado ? null : onRechazar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Rechazar', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: deshabilitado ? null : onAceptar,
                  style: ElevatedButton.styleFrom(backgroundColor: GoPickupColors.verde, padding: const EdgeInsets.symmetric(vertical: 8)),
                  child: const Text('Aceptar', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
