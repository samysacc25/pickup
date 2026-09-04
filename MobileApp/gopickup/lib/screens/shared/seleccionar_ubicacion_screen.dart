import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/go_pickup_theme.dart';
import '../../services/places_service.dart';

class _LugarRapido {
  final String nombre;
  final double lat;
  final double lng;
  const _LugarRapido(this.nombre, this.lat, this.lng);
}

const List<_LugarRapido> _lugaresRapidosTungurahua = [
  _LugarRapido('Terminal Terrestre Ambato', -1.2411, -78.6144),
  _LugarRapido('Parque Cevallos', -1.2432, -78.6236),
  _LugarRapido('Mercado Mayorista Ambato', -1.2536, -78.6303),
  _LugarRapido('UTA - Universidad Técnica de Ambato', -1.2495, -78.6180),
  _LugarRapido('Mall de los Andes', -1.2308, -78.6155),
  _LugarRapido('Quisapincha', -1.2331, -78.6975),
];

class SeleccionarUbicacionScreen extends StatefulWidget {
  final String titulo;
  final LatLng? ubicacionInicial;

  const SeleccionarUbicacionScreen({super.key, required this.titulo, this.ubicacionInicial});

  @override
  State<SeleccionarUbicacionScreen> createState() => _SeleccionarUbicacionScreenState();
}

class _SeleccionarUbicacionScreenState extends State<SeleccionarUbicacionScreen> {
  final _placesService = PlacesService();
  final _busquedaCtrl = TextEditingController();
  GoogleMapController? _mapController;

  LatLng _centroActual = const LatLng(-1.2417, -78.6197);
  String _direccionActual = 'Mueve el mapa para elegir el punto exacto';
  List<SugerenciaLugar> _sugerencias = [];
  bool _buscando = false;
  bool _cargandoDireccion = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.ubicacionInicial != null) {
      _centroActual = widget.ubicacionInicial!;
      _actualizarDireccionDelCentro();
    } else {
      _usarUbicacionActual();
    }
  }

  Future<void> _usarUbicacionActual() async {
    try {
      final permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) await Geolocator.requestPermission();
      final posicion = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final punto = LatLng(posicion.latitude, posicion.longitude);
      setState(() => _centroActual = punto);
      _mapController?.animateCamera(CameraUpdate.newLatLng(punto));
      _actualizarDireccionDelCentro();
    } catch (_) {}
  }

  void _alMoverMapa(CameraPosition posicion) {
    _centroActual = posicion.target;
  }

  void _alDejarDeMoverMapa() {
    _actualizarDireccionDelCentro();
  }

  Future<void> _actualizarDireccionDelCentro() async {
    setState(() => _cargandoDireccion = true);
    final direccion = await _placesService.direccionDesdeCoordenadas(_centroActual.latitude, _centroActual.longitude);
    if (!mounted) return;
    setState(() {
      _direccionActual = direccion ?? 'Ubicación seleccionada en el mapa';
      _cargandoDireccion = false;
    });
  }

  void _alEscribirBusqueda(String texto) {
    _debounce?.cancel();
    if (texto.trim().length < 3) {
      setState(() => _sugerencias = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _buscando = true);
      final resultados = await _placesService.buscarSugerencias(texto);
      if (!mounted) return;
      setState(() {
        _sugerencias = resultados;
        _buscando = false;
      });
    });
  }

  Future<void> _seleccionarSugerencia(SugerenciaLugar sugerencia) async {
    setState(() => _buscando = true);
    final detalle = await _placesService.obtenerDetalleLugar(sugerencia.placeId);
    if (!mounted) return;
    setState(() => _buscando = false);

    if (detalle != null) {
      _irAPunto(LatLng(detalle.latitud, detalle.longitud), detalle.direccion);
    }
  }

  void _seleccionarLugarRapido(_LugarRapido lugar) {
    _irAPunto(LatLng(lugar.lat, lugar.lng), lugar.nombre);
  }

  void _irAPunto(LatLng punto, String direccion) {
    setState(() {
      _centroActual = punto;
      _direccionActual = direccion;
      _sugerencias = [];
      _busquedaCtrl.clear();
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(punto));
  }

  void _confirmar() {
    Navigator.of(context).pop(UbicacionSeleccionada(
      latitud: _centroActual.latitude,
      longitud: _centroActual.longitude,
      direccion: _direccionActual,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _centroActual, zoom: 15),
            onMapCreated: (c) => _mapController = c,
            onCameraMove: _alMoverMapa,
            onCameraIdle: _alDejarDeMoverMapa,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.location_pin, size: 46, color: GoPickupColors.verdeOscuro),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 3,
                          child: TextField(
                            controller: _busquedaCtrl,
                            onChanged: _alEscribirBusqueda,
                            decoration: InputDecoration(
                              hintText: widget.titulo,
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _buscando
                                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 2)))
                                  : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_sugerencias.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)]),
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _sugerencias.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = _sugerencias[i];
                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined, color: GoPickupColors.verde),
                            title: Text(s.descripcion, style: const TextStyle(fontSize: 13)),
                            onTap: () => _seleccionarSugerencia(s),
                          );
                        },
                      ),
                    ),
                  if (_sugerencias.isEmpty && _busquedaCtrl.text.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _lugaresRapidosTungurahua.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final lugar = _lugaresRapidosTungurahua[i];
                          return ActionChip(
                            backgroundColor: Colors.white,
                            avatar: const Icon(Icons.place_outlined, size: 16, color: GoPickupColors.verdeOscuro),
                            label: Text(lugar.nombre, style: const TextStyle(fontSize: 12)),
                            onPressed: () => _seleccionarLugarRapido(lugar),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_pin, color: GoPickupColors.verdeOscuro),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _cargandoDireccion
                              ? const Text('Buscando dirección...', style: TextStyle(color: Colors.grey))
                              : Text(_direccionActual, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _cargandoDireccion ? null : _confirmar, child: const Text('Confirmar esta ubicación')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }
}
