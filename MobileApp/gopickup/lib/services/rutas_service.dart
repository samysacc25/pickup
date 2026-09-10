import 'dart:convert';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'api_client.dart';
import 'calculadora_eta.dart';
import '../config/api_config.dart';

// Ruta real por calles entre dos puntos, calculada con la Directions API de
// Google. Antes la app solo estimaba en línea recta (distancia haversine a
// 28 km/h), así que ni el conductor veía por dónde ir ni el tiempo de
// llegada tenía en cuenta las calles ni el tráfico.
class RutaCalculada {
  // Puntos de la línea a dibujar sobre el mapa.
  final List<LatLng> puntos;
  final double distanciaKm;
  final int minutos;

  // true cuando no se pudo consultar la ruta real y el resultado viene de la
  // estimación en línea recta (así la pantalla puede matizar el texto).
  final bool esEstimacion;

  RutaCalculada({
    required this.puntos,
    required this.distanciaKm,
    required this.minutos,
    this.esEstimacion = false,
  });
}

class RutasService {
  static const _url = 'https://maps.googleapis.com/maps/api/directions/json';

  // Devuelve la mejor ruta en auto entre los dos puntos. Si la Directions
  // API no responde (sin internet, cuota agotada, API no habilitada en
  // Google Cloud), devuelve una estimación en línea recta para que la app
  // siga mostrando un tiempo aproximado en vez de quedarse en blanco.
  static Future<RutaCalculada> obtenerRuta({required LatLng origen, required LatLng destino}) async {
    try {
      final uri = Uri.parse(
        '$_url'
        '?origin=${origen.latitude},${origen.longitude}'
        '&destination=${destino.latitude},${destino.longitude}'
        '&mode=driving'
        '&departure_time=now'
        '&language=es'
        '&key=${ApiConfig.googlePlacesApiKey}',
      );

      final respuesta = await ApiClient.get(uri);
      if (respuesta.statusCode == 200) {
        final data = jsonDecode(utf8.decode(respuesta.bodyBytes));
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final ruta = data['routes'][0];
          final tramo = (ruta['legs'] as List).first;

          // duration_in_traffic solo viene cuando Google tiene datos de
          // tráfico para esa vía y hora; si no, se usa la duración normal.
          final segundos = (tramo['duration_in_traffic']?['value'] ?? tramo['duration']['value']) as int;
          final metros = tramo['distance']['value'] as int;

          return RutaCalculada(
            puntos: _decodificarPolilinea(ruta['overview_polyline']['points'] as String),
            distanciaKm: metros / 1000.0,
            minutos: max(1, (segundos / 60).round()),
          );
        }
      }
    } catch (_) {
      // Se cae al respaldo de abajo.
    }

    return _estimacionEnLineaRecta(origen, destino);
  }

  static RutaCalculada _estimacionEnLineaRecta(LatLng origen, LatLng destino) {
    return RutaCalculada(
      puntos: [origen, destino],
      distanciaKm: CalculadoraEta.distanciaKm(origen.latitude, origen.longitude, destino.latitude, destino.longitude),
      minutos: CalculadoraEta.minutosEstimados(origen.latitude, origen.longitude, destino.latitude, destino.longitude),
      esEstimacion: true,
    );
  }

  // Google devuelve la ruta comprimida en el formato "encoded polyline".
  // Este es el algoritmo estándar para expandirla a coordenadas.
  static List<LatLng> _decodificarPolilinea(String codificada) {
    final puntos = <LatLng>[];
    var indice = 0;
    var lat = 0;
    var lng = 0;

    while (indice < codificada.length) {
      int resultado = 0, desplazamiento = 0, byte;

      do {
        byte = codificada.codeUnitAt(indice++) - 63;
        resultado |= (byte & 0x1F) << desplazamiento;
        desplazamiento += 5;
      } while (byte >= 0x20);
      lat += (resultado & 1) != 0 ? ~(resultado >> 1) : (resultado >> 1);

      resultado = 0;
      desplazamiento = 0;
      do {
        byte = codificada.codeUnitAt(indice++) - 63;
        resultado |= (byte & 0x1F) << desplazamiento;
        desplazamiento += 5;
      } while (byte >= 0x20);
      lng += (resultado & 1) != 0 ? ~(resultado >> 1) : (resultado >> 1);

      puntos.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return puntos;
  }
}

// Mantiene la ruta actualizada mientras el conductor se mueve, pero sin
// consultar la Directions API en cada actualización de GPS (llegan cada 8
// segundos y cada consulta se cobra). Solo vuelve a pedirla cuando cambia
// el destino, cuando el conductor ya se alejó lo suficiente del punto donde
// se calculó, o cuando pasó un minuto desde la última consulta.
class SeguidorRuta {
  RutaCalculada? ruta;

  LatLng? _origenCalculo;
  LatLng? _destinoCalculo;
  DateTime? _ultimaConsulta;
  bool _consultando = false;

  static const double _metrosParaRecalcular = 150;
  static const Duration _tiempoParaRecalcular = Duration(seconds: 60);

  // Devuelve true si la ruta cambió (para que la pantalla haga setState).
  Future<bool> actualizar({required LatLng origen, required LatLng destino}) async {
    if (_consultando) return false;

    if (!_necesitaRecalcular(origen, destino)) return false;

    _consultando = true;
    try {
      final nueva = await RutasService.obtenerRuta(origen: origen, destino: destino);
      ruta = nueva;
      _origenCalculo = origen;
      _destinoCalculo = destino;
      _ultimaConsulta = DateTime.now();
      return true;
    } catch (_) {
      return false;
    } finally {
      _consultando = false;
    }
  }

  bool _necesitaRecalcular(LatLng origen, LatLng destino) {
    if (ruta == null || _origenCalculo == null || _destinoCalculo == null) return true;

    // Un destino distinto (por ejemplo, el conductor ya recogió al cliente y
    // ahora la ruta va hacia el destino final) siempre obliga a recalcular.
    if (_metrosEntre(destino, _destinoCalculo!) > 50) return true;

    final metrosAvanzados = _metrosEntre(origen, _origenCalculo!);
    if (metrosAvanzados > _metrosParaRecalcular) return true;

    // Refresco por tiempo (para que el tráfico se refleje) solo si el punto
    // de partida se está moviendo de verdad. Si nada cambió -- por ejemplo
    // el cliente mirando la ruta de su viaje mientras espera conductor --
    // no tiene sentido volver a consultar (y pagar) la misma ruta.
    if (metrosAvanzados > 20) {
      final ultima = _ultimaConsulta;
      if (ultima == null || DateTime.now().difference(ultima) > _tiempoParaRecalcular) return true;
    }

    return false;
  }

  double _metrosEntre(LatLng a, LatLng b) =>
      CalculadoraEta.distanciaKm(a.latitude, a.longitude, b.latitude, b.longitude) * 1000;

  void limpiar() {
    ruta = null;
    _origenCalculo = null;
    _destinoCalculo = null;
    _ultimaConsulta = null;
  }
}
