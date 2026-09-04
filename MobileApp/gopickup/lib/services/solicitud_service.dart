import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/solicitud.dart';

class SolicitudService {
  final String token;
  SolicitudService(this.token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<Solicitud> crearSolicitud({
    required double origenLat,
    required double origenLng,
    required String origenDireccion,
    required double destinoLat,
    required double destinoLng,
    required String destinoDireccion,
    String? descripcionCarga,
    required bool llevaCarga,
    required TipoCamioneta tipoCamionetaRequerida,
    required MetodoPago metodoPago,
    double? tarifaPropuesta,
  }) async {
    final respuesta = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes'),
      headers: _headers,
      body: jsonEncode({
        'origenLatitud': origenLat,
        'origenLongitud': origenLng,
        'origenDireccion': origenDireccion,
        'destinoLatitud': destinoLat,
        'destinoLongitud': destinoLng,
        'destinoDireccion': destinoDireccion,
        'descripcionCarga': descripcionCarga,
        'llevaCarga': llevaCarga,
        'tipoCamionetaRequerida': tipoCamionetaANumero(tipoCamionetaRequerida),
        'metodoPago': metodoPagoANumero(metodoPago),
        'tarifaPropuesta': tarifaPropuesta,
      }),
    );

    if (respuesta.statusCode == 200) {
      return Solicitud.fromJson(jsonDecode(utf8.decode(respuesta.bodyBytes)));
    }
    final error = jsonDecode(utf8.decode(respuesta.bodyBytes));
    throw Exception(error['mensaje'] ?? 'No se pudo crear la solicitud.');
  }

  Future<Solicitud> obtenerSolicitud(int id) async {
    final respuesta = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$id'),
      headers: _headers,
    );
    if (respuesta.statusCode == 200) {
      return Solicitud.fromJson(jsonDecode(utf8.decode(respuesta.bodyBytes)));
    }
    throw Exception('No se pudo obtener el estado de la solicitud.');
  }

  Future<List<Solicitud>> misSolicitudes() async {
    final respuesta = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/mis-solicitudes'),
      headers: _headers,
    );
    if (respuesta.statusCode == 200) {
      final lista = jsonDecode(utf8.decode(respuesta.bodyBytes)) as List;
      return lista.map((e) => Solicitud.fromJson(e)).toList();
    }
    throw Exception('No se pudo obtener el historial.');
  }

  Future<void> cancelarSolicitud(int id, {String? motivo}) async {
    final respuesta = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$id/cancelar'),
      headers: _headers,
      body: jsonEncode({'motivo': motivo}),
    );
    if (respuesta.statusCode != 200) {
      throw Exception('No se pudo cancelar la solicitud.');
    }
  }

  Future<void> calificarConductor(int solicitudId, int calificacion) async {
    final respuesta = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$solicitudId/calificar-conductor'),
      headers: _headers,
      body: jsonEncode({'calificacion': calificacion}),
    );
    if (respuesta.statusCode != 204) {
      throw Exception('No se pudo enviar la calificación.');
    }
  }

  Future<List<Solicitud>> solicitudesDisponibles() async {
    final respuesta = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/disponibles'),
      headers: _headers,
    );
    if (respuesta.statusCode == 200) {
      final lista = jsonDecode(utf8.decode(respuesta.bodyBytes)) as List;
      return lista.map((e) => Solicitud.fromJson(e)).toList();
    }
    throw Exception('No se pudo obtener las solicitudes disponibles.');
  }

  Future<Solicitud> aceptarSolicitud(int id) async {
    final respuesta = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$id/aceptar'),
      headers: _headers,
    );
    if (respuesta.statusCode == 200) {
      return Solicitud.fromJson(jsonDecode(utf8.decode(respuesta.bodyBytes)));
    }
    final error = jsonDecode(utf8.decode(respuesta.bodyBytes));
    throw Exception(error['mensaje'] ?? 'No se pudo aceptar la solicitud.');
  }

  Future<Solicitud> marcarEnCamino(int id) => _cambiarEstado(id, 'en-camino');
  Future<Solicitud> iniciarServicio(int id) => _cambiarEstado(id, 'iniciar');
  Future<Solicitud> finalizarServicio(int id) => _cambiarEstado(id, 'finalizar');

  Future<Solicitud> _cambiarEstado(int id, String accion) async {
    final respuesta = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$id/$accion'),
      headers: _headers,
    );
    if (respuesta.statusCode == 200) {
      return Solicitud.fromJson(jsonDecode(utf8.decode(respuesta.bodyBytes)));
    }
    final error = jsonDecode(utf8.decode(respuesta.bodyBytes));
    throw Exception(error['mensaje'] ?? 'No se pudo actualizar el estado del servicio.');
  }

  // Respaldo por HTTP del chat (además del envío por SignalR). No se guarda
  // nada en la base de datos, solo se retransmite en vivo al otro participante.
  Future<void> enviarMensajeChat(int solicitudId, String mensaje) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$solicitudId/mensaje-chat'),
      headers: _headers,
      body: jsonEncode({'mensaje': mensaje}),
    );
  }
}
