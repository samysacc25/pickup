import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class SugerenciaLugar {
  final String descripcion;
  final String placeId;

  SugerenciaLugar({required this.descripcion, required this.placeId});
}

class UbicacionSeleccionada {
  final double latitud;
  final double longitud;
  final String direccion;

  UbicacionSeleccionada({required this.latitud, required this.longitud, required this.direccion});
}

class PlacesService {
  static const _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  Future<List<SugerenciaLugar>> buscarSugerencias(String texto) async {
    if (texto.trim().length < 3) return [];

    final uri = Uri.parse(
      '$_baseUrl/autocomplete/json'
      '?input=${Uri.encodeComponent(texto)}'
      '&components=country:ec'
      '&location=-1.2417,-78.6197'
      '&radius=60000'
      '&language=es'
      '&key=${ApiConfig.googlePlacesApiKey}',
    );

    final respuesta = await http.get(uri);
    if (respuesta.statusCode != 200) return [];

    final data = jsonDecode(respuesta.body);
    if (data['status'] != 'OK') return [];

    final predicciones = data['predictions'] as List;
    return predicciones
        .map((p) => SugerenciaLugar(descripcion: p['description'], placeId: p['place_id']))
        .toList();
  }

  Future<UbicacionSeleccionada?> obtenerDetalleLugar(String placeId) async {
    final uri = Uri.parse(
      '$_baseUrl/details/json'
      '?place_id=$placeId'
      '&fields=geometry,formatted_address,address_component'
      '&language=es'
      '&key=${ApiConfig.googlePlacesApiKey}',
    );

    final respuesta = await http.get(uri);
    if (respuesta.statusCode != 200) return null;

    final data = jsonDecode(respuesta.body);
    if (data['status'] != 'OK') return null;

    final resultado = data['result'];
    final ubicacion = resultado['geometry']['location'];
    final direccion = _construirDireccionLegible(resultado['address_components'], resultado['formatted_address']);

    return UbicacionSeleccionada(
      latitud: (ubicacion['lat'] as num).toDouble(),
      longitud: (ubicacion['lng'] as num).toDouble(),
      direccion: direccion,
    );
  }

  // Convierte coordenadas a una dirección legible con nombre de calle, tanto
  // para el punto de recogida como para el destino. Evita mostrar "Plus Codes"
  // (ej. "Q99H+FX2") que Google a veces devuelve como formatted_address
  // cuando no hay una dirección oficial exacta en ese punto.
  Future<String?> direccionDesdeCoordenadas(double lat, double lng) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng'
      '&language=es'
      '&result_type=street_address|route|premise|point_of_interest'
      '&key=${ApiConfig.googlePlacesApiKey}',
    );

    final respuesta = await http.get(uri);
    if (respuesta.statusCode != 200) return null;

    var data = jsonDecode(respuesta.body);

    // Si el filtro de result_type no encuentra nada (zona rural sin calle
    // catalogada), reintentamos sin filtro para al menos tener algo cercano.
    if (data['status'] != 'OK' || (data['results'] as List).isEmpty) {
      final uriSinFiltro = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&language=es&key=${ApiConfig.googlePlacesApiKey}',
      );
      final respuesta2 = await http.get(uriSinFiltro);
      if (respuesta2.statusCode != 200) return null;
      data = jsonDecode(respuesta2.body);
      if (data['status'] != 'OK' || (data['results'] as List).isEmpty) return null;
    }

    final resultados = data['results'] as List;
    final primero = resultados.first;
    return _construirDireccionLegible(primero['address_components'], primero['formatted_address']);
  }

  // Arma "Calle/Avenida + referencia" a partir de los componentes, en vez de
  // usar directamente formatted_address (que puede ser un Plus Code).
  String _construirDireccionLegible(dynamic addressComponents, String? formattedAddress) {
    String? calle;
    String? numero;
    String? sector;
    String? ciudad;

    if (addressComponents is List) {
      for (final comp in addressComponents) {
        final tipos = (comp['types'] as List).cast<String>();
        if (tipos.contains('route')) calle = comp['long_name'];
        if (tipos.contains('street_number')) numero = comp['long_name'];
        if (tipos.contains('neighborhood') || tipos.contains('sublocality')) sector ??= comp['long_name'];
        if (tipos.contains('locality')) ciudad = comp['long_name'];
      }
    }

    // Si Google sí encontró un nombre de calle real, lo priorizamos.
    if (calle != null && calle.trim().isNotEmpty) {
      final partes = <String>[
        if (numero != null) '$calle $numero' else calle,
        if (sector != null) sector,
        if (ciudad != null) ciudad,
      ];
      return partes.join(', ');
    }

    // Si no hay calle catalogada pero el formatted_address NO es un Plus Code
    // (los Plus Codes empiezan con un patrón tipo "XXXX+XX"), lo usamos.
    if (formattedAddress != null && !RegExp(r'^[A-Z0-9]{4,}\+[A-Z0-9]{2,}').hasMatch(formattedAddress)) {
      return formattedAddress;
    }

    // Último recurso: sector + ciudad, o "Ubicación seleccionada".
    if (sector != null || ciudad != null) {
      return [sector, ciudad].where((e) => e != null).join(', ');
    }

    return formattedAddress ?? 'Ubicación seleccionada';
  }
}
