import 'solicitud.dart';

enum EstadoOferta { pendiente, aceptada, rechazada }

EstadoOferta estadoOfertaDesdeNumero(int valor) {
  const mapa = {
    1: EstadoOferta.pendiente,
    2: EstadoOferta.aceptada,
    3: EstadoOferta.rechazada,
  };
  return mapa[valor] ?? EstadoOferta.pendiente;
}

// Oferta de precio que un conductor le hace al cliente sobre una solicitud
// que sigue buscando conductor. El cliente ve todas las que recibe y decide
// cuál acepta.
class Oferta {
  final int id;
  final int solicitudId;
  final int conductorId;
  final String conductorNombre;
  final double calificacionConductor;
  final String? vehiculoPlaca;
  final String? vehiculoDescripcion;
  final TipoCamioneta? vehiculoTipo;
  final double monto;
  final EstadoOferta estado;
  final double? conductorLatitud;
  final double? conductorLongitud;
  final double? distanciaAlOrigenKm;
  final int? minutosLlegadaEstimados;
  final DateTime fechaCreacion;

  Oferta({
    required this.id,
    required this.solicitudId,
    required this.conductorId,
    required this.conductorNombre,
    required this.calificacionConductor,
    this.vehiculoPlaca,
    this.vehiculoDescripcion,
    this.vehiculoTipo,
    required this.monto,
    required this.estado,
    this.conductorLatitud,
    this.conductorLongitud,
    this.distanciaAlOrigenKm,
    this.minutosLlegadaEstimados,
    required this.fechaCreacion,
  });

  factory Oferta.fromJson(Map<String, dynamic> json) {
    return Oferta(
      id: json['id'],
      solicitudId: json['solicitudId'],
      conductorId: json['conductorId'],
      conductorNombre: json['conductorNombre'] ?? '',
      calificacionConductor: (json['calificacionConductor'] as num?)?.toDouble() ?? 5.0,
      vehiculoPlaca: json['vehiculoPlaca'],
      vehiculoDescripcion: json['vehiculoDescripcion'],
      vehiculoTipo: json['vehiculoTipo'] != null ? tipoCamionetaDesdeNumero(json['vehiculoTipo']) : null,
      monto: (json['monto'] as num).toDouble(),
      estado: estadoOfertaDesdeNumero(json['estado'] ?? 1),
      conductorLatitud: (json['conductorLatitud'] as num?)?.toDouble(),
      conductorLongitud: (json['conductorLongitud'] as num?)?.toDouble(),
      distanciaAlOrigenKm: (json['distanciaAlOrigenKm'] as num?)?.toDouble(),
      minutosLlegadaEstimados: json['minutosLlegadaEstimados'],
      fechaCreacion: DateTime.parse(json['fechaCreacion']),
    );
  }
}
