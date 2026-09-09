import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../config/api_config.dart';
import '../models/solicitud.dart';
import 'solicitud_hub_service.dart' show MensajeChat;

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
    final respuesta = await ApiClient.post(
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
    throw Exception(ApiClient.mensajeDeError(respuesta, 'No se pudo crear la solicitud.'));
  }

  Future<Solicitud> obtenerSolicitud(int id) async {
    final respuesta = await ApiClient.get(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$id'),
      headers: _headers,
    );
    if (respuesta.statusCode == 200) {
      return Solicitud.fromJson(jsonDecode(utf8.decode(respuesta.bodyBytes)));
    }
    throw Exception('No se pudo obtener el estado de la solicitud.');
  }

  Future<List<Solicitud>> misSolicitudes() async {
    final respuesta = await ApiClient.get(
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
    final respuesta = await ApiClient.put(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$id/cancelar'),
      headers: _headers,
      body: jsonEncode({'motivo': motivo}),
    );
    if (respuesta.statusCode != 200) {
      throw Exception('No se pudo cancelar la solicitud.');
    }
  }

  Future<void> calificarConductor(int solicitudId, int calificacion) async {
    final respuesta = await ApiClient.put(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$solicitudId/calificar-conductor'),
      headers: _headers,
      body: jsonEncode({'calificacion': calificacion}),
    );
    if (respuesta.statusCode != 204) {
      throw Exception('No se pudo enviar la calificación.');
    }
  }

  Future<List<Solicitud>> solicitudesDisponibles() async {
    final respuesta = await ApiClient.get(
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
    final respuesta = await ApiClient.post(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$id/aceptar'),
      headers: _headers,
    );
    if (respuesta.statusCode == 200) {
      return Solicitud.fromJson(jsonDecode(utf8.decode(respuesta.bodyBytes)));
    }
    throw Exception(ApiClient.mensajeDeError(respuesta, 'No se pudo aceptar la solicitud.'));
  }

  Future<Solicitud> marcarEnCamino(int id) => _cambiarEstado(id, 'en-camino');
  Future<Solicitud> iniciarServicio(int id) => _cambiarEstado(id, 'iniciar');
  Future<Solicitud> finalizarServicio(int id) => _cambiarEstado(id, 'finalizar');

  Future<Solicitud> _cambiarEstado(int id, String accion) async {
    final respuesta = await ApiClient.put(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$id/$accion'),
      headers: _headers,
    );
    if (respuesta.statusCode == 200) {
      return Solicitud.fromJson(jsonDecode(utf8.decode(respuesta.bodyBytes)));
    }
    throw Exception(ApiClient.mensajeDeError(respuesta, 'No se pudo actualizar el estado del servicio.'));
  }

  // Respaldo por HTTP del chat (además del envío por SignalR). El mensaje
  // queda guardado mientras la solicitud siga activa (se borra al finalizar
  // o cancelarse), para que sobreviva si el usuario cierra la pantalla de
  // chat o navega fuera y vuelve.
  Future<void> enviarMensajeChat(int solicitudId, String mensaje) async {
    await ApiClient.post(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$solicitudId/mensaje-chat'),
      headers: _headers,
      body: jsonEncode({'mensaje': mensaje}),
    );
  }

  // Trae el historial de chat guardado hasta el momento, para que al abrir
  // (o reabrir) la pantalla de chat no se pierda la conversación anterior.
  Future<List<MensajeChat>> obtenerMensajesChat(int solicitudId) async {
    final respuesta = await ApiClient.get(
      Uri.parse('${ApiConfig.baseUrl}/solicitudes/$solicitudId/mensajes-chat'),
      headers: _headers,
    );
    if (respuesta.statusCode != 200) return [];
    final lista = jsonDecode(utf8.decode(respuesta.bodyBytes)) as List;
    return lista
        .map((m) => MensajeChat(
              remitente: m['remitente'] ?? '',
              texto: m['texto'] ?? '',
              fecha: DateTime.parse(m['fecha']),
            ))
        .toList();
  }
}
