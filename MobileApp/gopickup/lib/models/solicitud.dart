enum EstadoSolicitud {
  buscando,
  aceptada,
  enCamino,
  iniciada,
  finalizada,
  canceladaCliente,
  canceladaConductor,
  sinConductores,
}

EstadoSolicitud estadoDesdeNumero(int valor) {
  const mapa = {
    1: EstadoSolicitud.buscando,
    2: EstadoSolicitud.aceptada,
    3: EstadoSolicitud.enCamino,
    4: EstadoSolicitud.iniciada,
    5: EstadoSolicitud.finalizada,
    6: EstadoSolicitud.canceladaCliente,
    7: EstadoSolicitud.canceladaConductor,
    8: EstadoSolicitud.sinConductores,
  };
  return mapa[valor] ?? EstadoSolicitud.buscando;
}

String textoEstado(EstadoSolicitud estado) {
  switch (estado) {
    case EstadoSolicitud.buscando:
      return 'Buscando conductor disponible...';
    case EstadoSolicitud.aceptada:
      return 'Conductor asignado';
    case EstadoSolicitud.enCamino:
      return 'El conductor va en camino';
    case EstadoSolicitud.iniciada:
      return 'Viaje en curso';
    case EstadoSolicitud.finalizada:
      return 'Viaje finalizado';
    case EstadoSolicitud.canceladaCliente:
      return 'Cancelado por ti';
    case EstadoSolicitud.canceladaConductor:
      return 'Cancelado por el conductor';
    case EstadoSolicitud.sinConductores:
      return 'No hay conductores disponibles';
  }
}

enum TipoCamioneta { pequena, mediana, grande }

TipoCamioneta tipoCamionetaDesdeNumero(int valor) {
  const mapa = {1: TipoCamioneta.pequena, 2: TipoCamioneta.mediana, 3: TipoCamioneta.grande};
  return mapa[valor] ?? TipoCamioneta.pequena;
}

int tipoCamionetaANumero(TipoCamioneta tipo) {
  const mapa = {TipoCamioneta.pequena: 1, TipoCamioneta.mediana: 2, TipoCamioneta.grande: 3};
  return mapa[tipo]!;
}

String textoTipoCamioneta(TipoCamioneta tipo) {
  switch (tipo) {
    case TipoCamioneta.pequena:
      return 'Pequeña (cabina simple)';
    case TipoCamioneta.mediana:
      return 'Mediana (doble cabina)';
    case TipoCamioneta.grande:
      return 'Grande (estaca larga)';
  }
}

enum MetodoPago { efectivo, transferencia, deUna }

int metodoPagoANumero(MetodoPago metodo) {
  const mapa = {MetodoPago.efectivo: 1, MetodoPago.transferencia: 2, MetodoPago.deUna: 3};
  return mapa[metodo]!;
}

String textoMetodoPago(MetodoPago metodo) {
  switch (metodo) {
    case MetodoPago.efectivo:
      return 'Efectivo';
    case MetodoPago.transferencia:
      return 'Transferencia bancaria';
    case MetodoPago.deUna:
      return 'DeUna';
  }
}

class Solicitud {
  final int id;
  final EstadoSolicitud estado;
  final String clienteNombre;
  final String? clienteTelefono;
  final int? conductorId;
  final String? conductorNombre;
  final String? conductorTelefono;
  final String? vehiculoPlaca;
  final String? vehiculoDescripcion;
  final TipoCamioneta? vehiculoTipo;
  final double? conductorLatitud;
  final double? conductorLongitud;
  final double origenLatitud;
  final double origenLongitud;
  final String origenDireccion;
  final double destinoLatitud;
  final double destinoLongitud;
  final String destinoDireccion;
  final String? descripcionCarga;
  final bool llevaCarga;
  final bool esInterprovincial;
  final double tarifaSugerida;
  final double? tarifaPropuestaCliente;
  final double? tarifaAcordada;
  final double? tarifaFinal;
  final double? recargoAplicado;
  final double? distanciaKm;
  final int? duracionEstimadaMin;
  final DateTime fechaSolicitud;

  Solicitud({
    required this.id,
    required this.estado,
    required this.clienteNombre,
    this.clienteTelefono,
    this.conductorId,
    this.conductorNombre,
    this.conductorTelefono,
    this.vehiculoPlaca,
    this.vehiculoDescripcion,
    this.vehiculoTipo,
    this.conductorLatitud,
    this.conductorLongitud,
    required this.origenLatitud,
    required this.origenLongitud,
    required this.origenDireccion,
    required this.destinoLatitud,
    required this.destinoLongitud,
    required this.destinoDireccion,
    this.descripcionCarga,
    required this.llevaCarga,
    required this.esInterprovincial,
    required this.tarifaSugerida,
    this.tarifaPropuestaCliente,
    this.tarifaAcordada,
    this.tarifaFinal,
    this.recargoAplicado,
    this.distanciaKm,
    this.duracionEstimadaMin,
    required this.fechaSolicitud,
  });

  factory Solicitud.fromJson(Map<String, dynamic> json) {
    return Solicitud(
      id: json['id'],
      estado: estadoDesdeNumero(json['estado']),
      clienteNombre: json['clienteNombre'] ?? '',
      clienteTelefono: json['clienteTelefono'],
      conductorId: json['conductorId'],
      conductorNombre: json['conductorNombre'],
      conductorTelefono: json['conductorTelefono'],
      vehiculoPlaca: json['vehiculoPlaca'],
      vehiculoDescripcion: json['vehiculoDescripcion'],
      vehiculoTipo: json['vehiculoTipo'] != null ? tipoCamionetaDesdeNumero(json['vehiculoTipo']) : null,
      conductorLatitud: (json['conductorLatitud'] as num?)?.toDouble(),
      conductorLongitud: (json['conductorLongitud'] as num?)?.toDouble(),
      origenLatitud: (json['origenLatitud'] as num).toDouble(),
      origenLongitud: (json['origenLongitud'] as num).toDouble(),
      origenDireccion: json['origenDireccion'] ?? '',
      destinoLatitud: (json['destinoLatitud'] as num).toDouble(),
      destinoLongitud: (json['destinoLongitud'] as num).toDouble(),
      destinoDireccion: json['destinoDireccion'] ?? '',
      descripcionCarga: json['descripcionCarga'],
      llevaCarga: json['llevaCarga'] ?? false,
      esInterprovincial: json['esInterprovincial'] ?? false,
      tarifaSugerida: (json['tarifaSugerida'] as num?)?.toDouble() ?? 0,
      tarifaPropuestaCliente: (json['tarifaPropuestaCliente'] as num?)?.toDouble(),
      tarifaAcordada: (json['tarifaAcordada'] as num?)?.toDouble(),
      tarifaFinal: (json['tarifaFinal'] as num?)?.toDouble(),
      recargoAplicado: (json['recargoAplicado'] as num?)?.toDouble(),
      distanciaKm: (json['distanciaKm'] as num?)?.toDouble(),
      duracionEstimadaMin: json['duracionEstimadaMin'],
      fechaSolicitud: DateTime.parse(json['fechaSolicitud']),
    );
  }

  bool get estaActiva => estado == EstadoSolicitud.buscando ||
      estado == EstadoSolicitud.aceptada ||
      estado == EstadoSolicitud.enCamino ||
      estado == EstadoSolicitud.iniciada;
}
