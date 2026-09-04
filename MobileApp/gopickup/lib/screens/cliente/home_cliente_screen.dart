import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/go_pickup_theme.dart';
import '../../models/usuario.dart';
import '../../models/solicitud.dart';
import '../../services/auth_service.dart';
import '../../services/solicitud_service.dart';
import '../../services/places_service.dart';
import '../../services/push_notification_service.dart';
import '../../theme/responsive.dart';
import '../../widgets/notificacion.dart';
import '../login_screen.dart';
import '../shared/seleccionar_ubicacion_screen.dart';
import 'historial_cliente_screen.dart';
import 'solicitud_en_curso_screen.dart';

class HomeClienteScreen extends StatefulWidget {
  final SesionUsuario sesion;
  const HomeClienteScreen({super.key, required this.sesion});

  @override
  State<HomeClienteScreen> createState() => _HomeClienteScreenState();
}

class _HomeClienteScreenState extends State<HomeClienteScreen> {
  GoogleMapController? _mapController;

  UbicacionSeleccionada? _origen;
  UbicacionSeleccionada? _destino;

  final _descripcionCtrl = TextEditingController();
  final _tarifaPropuestaCtrl = TextEditingController();

  bool _llevaCarga = false;
  bool _ofrecerTarifaPropia = false;
  TipoCamioneta _tipoCamioneta = TipoCamioneta.pequena;
  MetodoPago _metodoPago = MetodoPago.efectivo;

  bool _solicitando = false;
  String? _error;

  static const CameraPosition _posicionInicial = CameraPosition(
    target: LatLng(-1.2417, -78.6197),
    zoom: 13,
  );

  @override
  void initState() {
    super.initState();
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
      final direccion = await PlacesService().direccionDesdeCoordenadas(posicion.latitude, posicion.longitude);

      setState(() {
        _origen = UbicacionSeleccionada(
          latitud: posicion.latitude,
          longitud: posicion.longitude,
          direccion: direccion ?? 'Mi ubicación actual',
        );
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(posicion.latitude, posicion.longitude)));
    } catch (_) {}
  }

  Future<void> _elegirOrigen() async {
    final resultado = await Navigator.of(context).push<UbicacionSeleccionada>(
      MaterialPageRoute(
        builder: (_) => SeleccionarUbicacionScreen(
          titulo: '¿Dónde te recogemos?',
          ubicacionInicial: _origen != null ? LatLng(_origen!.latitud, _origen!.longitud) : null,
        ),
      ),
    );
    if (resultado != null) setState(() => _origen = resultado);
  }

  Future<void> _elegirDestino() async {
    final resultado = await Navigator.of(context).push<UbicacionSeleccionada>(
      MaterialPageRoute(
        builder: (_) => SeleccionarUbicacionScreen(
          titulo: '¿A dónde vas?',
          ubicacionInicial: _destino != null ? LatLng(_destino!.latitud, _destino!.longitud) : null,
        ),
      ),
    );
    if (resultado != null) setState(() => _destino = resultado);
  }

  Future<void> _solicitarCamioneta() async {
    if (_origen == null) {
      mostrarError(context, 'Elige el punto donde te recogemos.');
      return;
    }
    if (_destino == null) {
      mostrarError(context, 'Elige tu destino.');
      return;
    }
    if (_llevaCarga && _descripcionCtrl.text.trim().isEmpty) {
      mostrarError(context, 'Describe brevemente qué carga llevas.');
      return;
    }

    setState(() {
      _solicitando = true;
      _error = null;
    });

    try {
      double? tarifaPropuesta;
      if (_ofrecerTarifaPropia) {
        tarifaPropuesta = double.tryParse(_tarifaPropuestaCtrl.text.trim());
        if (tarifaPropuesta == null || tarifaPropuesta <= 0) {
          throw Exception('Ingresa un monto válido para tu oferta.');
        }
      }

      final solicitudService = SolicitudService(widget.sesion.token);
      final Solicitud solicitud = await solicitudService.crearSolicitud(
        origenLat: _origen!.latitud,
        origenLng: _origen!.longitud,
        origenDireccion: _origen!.direccion,
        destinoLat: _destino!.latitud,
        destinoLng: _destino!.longitud,
        destinoDireccion: _destino!.direccion,
        descripcionCarga: _llevaCarga ? _descripcionCtrl.text.trim() : null,
        llevaCarga: _llevaCarga,
        tipoCamionetaRequerida: _tipoCamioneta,
        metodoPago: _metodoPago,
        tarifaPropuesta: tarifaPropuesta,
      );

      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SolicitudEnCursoScreen(sesion: widget.sesion, solicitudId: solicitud.id)));
    } catch (e) {
      setState(() => _error = textoError(e));
      mostrarError(context, textoError(e));
    } finally {
      if (mounted) setState(() => _solicitando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    await AuthService().cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.sesion.nombreCompleto.split(' ').first}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial de viajes',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HistorialClienteScreen(sesion: widget.sesion))),
          ),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Cerrar sesión', onPressed: _cerrarSesion),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _posicionInicial,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: {
              if (_origen != null)
                Marker(
                  markerId: const MarkerId('origen'),
                  position: LatLng(_origen!.latitud, _origen!.longitud),
                  infoWindow: const InfoWindow(title: 'Punto de recogida'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
              if (_destino != null)
                Marker(
                  markerId: const MarkerId('destino'),
                  position: LatLng(_destino!.latitud, _destino!.longitud),
                  infoWindow: const InfoWindow(title: 'Destino'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
            },
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.46,
            minChildSize: 0.14,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(context.responsive.esTablet ? 40 : 20, 12, context.responsive.esTablet ? 40 : 20, 24),
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                    ),
                    const SizedBox(height: 16),
                    const Text('¿A dónde te llevamos?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _CampoUbicacion(icono: Icons.my_location, color: GoPickupColors.verde, texto: _origen?.direccion ?? 'Elige el punto de recogida', onTap: _elegirOrigen),
                    const SizedBox(height: 8),
                    _CampoUbicacion(icono: Icons.location_on, color: Colors.red, texto: _destino?.direccion ?? 'Elige tu destino', onTap: _elegirDestino),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _llevaCarga,
                      onChanged: (v) => setState(() => _llevaCarga = v),
                      activeColor: GoPickupColors.verde,
                      title: const Text('Llevo carga adicional', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Marca esto si además de ti, viaja mercancía o algo que transportar (cambia la tarifa por km)', style: TextStyle(fontSize: 11)),
                    ),
                    if (_llevaCarga)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: TextField(
                          controller: _descripcionCtrl,
                          decoration: const InputDecoration(labelText: 'Describe brevemente la carga', prefixIcon: Icon(Icons.inventory_2_outlined)),
                        ),
                      ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<TipoCamioneta>(
                      value: _tipoCamioneta,
                      decoration: const InputDecoration(labelText: 'Tipo de camioneta', prefixIcon: Icon(Icons.local_shipping_outlined)),
                      items: TipoCamioneta.values.map((t) => DropdownMenuItem(value: t, child: Text(textoTipoCamioneta(t)))).toList(),
                      onChanged: (v) => setState(() => _tipoCamioneta = v ?? TipoCamioneta.pequena),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<MetodoPago>(
                      value: _metodoPago,
                      decoration: const InputDecoration(labelText: 'Método de pago', prefixIcon: Icon(Icons.payments_outlined)),
                      items: MetodoPago.values.map((m) => DropdownMenuItem(value: m, child: Text(textoMetodoPago(m)))).toList(),
                      onChanged: (v) => setState(() => _metodoPago = v ?? MetodoPago.efectivo),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _ofrecerTarifaPropia,
                      onChanged: (v) => setState(() => _ofrecerTarifaPropia = v),
                      activeColor: GoPickupColors.verde,
                      title: const Text('Quiero ofrecer mi propio precio', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Si lo desactivas, se usará la tarifa sugerida automática', style: TextStyle(fontSize: 11)),
                    ),
                    if (_ofrecerTarifaPropia)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextField(
                          controller: _tarifaPropuestaCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Tu oferta (USD)', prefixIcon: Icon(Icons.attach_money)),
                        ),
                      ),
                    if (_error != null)
                      Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _solicitando ? null : _solicitarCamioneta,
                      icon: _solicitando
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.local_shipping),
                      label: Text(_solicitando ? 'Enviando solicitud...' : 'Solicitar camioneta'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CampoUbicacion extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String texto;
  final VoidCallback onTap;

  const _CampoUbicacion({required this.icono, required this.color, required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: GoPickupColors.grisFondo, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
        child: Row(
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}
