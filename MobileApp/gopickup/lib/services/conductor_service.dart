import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

enum EstadoConductor { desconectado, disponible, enViaje, ocupado }

int estadoConductorANumero(EstadoConductor estado) {
  const mapa = {
    EstadoConductor.desconectado: 0,
    EstadoConductor.disponible: 1,
    EstadoConductor.enViaje: 2,
    EstadoConductor.ocupado: 3,
  };
  return mapa[estado]!;
}

class ConductorService {
  final String token;
  ConductorService(this.token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<void> cambiarEstado(EstadoConductor estado) async {
    final respuesta = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/conductores/estado'),
      headers: _headers,
      body: jsonEncode({'estado': estadoConductorANumero(estado)}),
    );
    if (respuesta.statusCode != 204) {
      final error = jsonDecode(utf8.decode(respuesta.bodyBytes));
      throw Exception(error['mensaje'] ?? 'No se pudo actualizar tu estado.');
    }
  }

  Future<void> actualizarUbicacion(double lat, double lng) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/conductores/ubicacion'),
      headers: _headers,
      body: jsonEncode({'latitud': lat, 'longitud': lng}),
    );
  }
}
