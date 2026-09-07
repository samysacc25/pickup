import 'dart:convert';
import 'api_client.dart';
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
    final respuesta = await ApiClient.put(
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
    await ApiClient.put(
      Uri.parse('${ApiConfig.baseUrl}/conductores/ubicacion'),
      headers: _headers,
      body: jsonEncode({'latitud': lat, 'longitud': lng}),
    );
  }

  // Consulta el estado real que tiene el conductor en el servidor. Se usa al
  // abrir la app para saber si sigue marcado como "Disponible" desde antes
  // (por ejemplo si cerró la app sin apagar la disponibilidad) y así
  // reconectar automáticamente en vez de mostrarlo como Desconectado hasta
  // que el conductor mueva el switch manualmente.
  Future<EstadoConductor?> obtenerEstadoActual() async {
    try {
      final respuesta = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}/conductores/perfil'),
        headers: _headers,
      );
      if (respuesta.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(respuesta.bodyBytes));
      final valor = data['estado'] as int?;
      if (valor == null) return null;
      const mapaInverso = {
        0: EstadoConductor.desconectado,
        1: EstadoConductor.disponible,
        2: EstadoConductor.enViaje,
        3: EstadoConductor.ocupado,
      };
      return mapaInverso[valor];
    } catch (_) {
      return null;
    }
  }
}
