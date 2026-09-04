import 'dart:math';

class CalculadoraEta {
  static const double _velocidadPromedioKmH = 28.0;

  static double distanciaKm(double lat1, double lon1, double lat2, double lon2) {
    const radioTierraKm = 6371.0;
    final dLat = _aRad(lat2 - lat1);
    final dLon = _aRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_aRad(lat1)) * cos(_aRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radioTierraKm * c;
  }

  static int minutosEstimados(double lat1, double lon1, double lat2, double lon2) {
    final distancia = distanciaKm(lat1, lon1, lat2, lon2);
    final horas = distancia / _velocidadPromedioKmH;
    final minutos = (horas * 60).ceil();
    return minutos < 1 ? 1 : minutos;
  }

  static double _aRad(double grados) => grados * pi / 180.0;
}

String textoEta(int minutos) {
  if (minutos <= 1) return 'Está llegando';
  if (minutos < 60) return 'Llega en ~$minutos min';
  final horas = (minutos / 60).floor();
  final resto = minutos % 60;
  return 'Llega en ~${horas}h ${resto}min';
}
