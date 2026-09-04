class SesionUsuario {
  final String token;
  final int usuarioId;
  final String nombreCompleto;
  final String rol;
  final int? conductorId;
  final String? estadoSolicitudConductor;

  SesionUsuario({
    required this.token,
    required this.usuarioId,
    required this.nombreCompleto,
    required this.rol,
    this.conductorId,
    this.estadoSolicitudConductor,
  });

  factory SesionUsuario.fromJson(Map<String, dynamic> json) {
    return SesionUsuario(
      token: json['token'],
      usuarioId: json['usuarioId'],
      nombreCompleto: json['nombreCompleto'],
      rol: json['rol'].toString(),
      conductorId: json['conductorId'],
      estadoSolicitudConductor: json['estadoSolicitudConductor']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'usuarioId': usuarioId,
        'nombreCompleto': nombreCompleto,
        'rol': rol,
        'conductorId': conductorId,
        'estadoSolicitudConductor': estadoSolicitudConductor,
      };

  bool get esCliente => rol == 'Cliente' || rol == '1';
  bool get esConductor => rol == 'Conductor' || rol == '2';
}
