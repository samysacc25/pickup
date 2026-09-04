import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/go_pickup_theme.dart';
import '../../models/usuario.dart';
import '../../models/solicitud.dart';
import '../../services/solicitud_service.dart';
import '../../services/solicitud_hub_service.dart';
import '../../services/calculadora_eta.dart';
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

  BitmapDescriptor? _iconoCamioneta;
  Solicitud? _solicitud;
  LatLng? _ubicacionConductor;
  int? _minutosEta;
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    _solicitudService = SolicitudService(widget.sesion.token);
    _hubService = SolicitudHubService(widget.sesion.token);
    _cargarIconoCamioneta();
    _cargarSolicitud();
    _conectarTiempoReal();
    _timerRespaldo = Timer.periodic(const Duration(seconds: 8), (_) => _cargarSolicitud());
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
    } catch (_) {}
  }

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

  Future<void> _conectarTiempoReal() async {
    await _hubService.conectarYUnirse(
      solicitudId: widget.solicitudId,
      alActualizarSolicitud: (viaje) {
        if (!mounted) return;
        setState(() => _solicitud = viaje);
      },
      alActualizarUbicacion: (lat, lng) {
        if (!mounted) return;
        setState(() {
          _ubicacionConductor = LatLng(lat, lng);
          _recalcularEta();
        });
      },
    );
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
    _hubService.desconectar();
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
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)]),
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
                        IconButton(icon: const Icon(Icons.phone, color: Colors.green), onPressed: () {}),
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
