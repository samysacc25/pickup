import 'dart:convert';
import 'api_client.dart';
import '../config/api_config.dart';

class VerificacionService {
  Future<Map<String, dynamic>> enviarCodigo(String telefono) async {
    final respuesta = await ApiClient.post(
      Uri.parse('${ApiConfig.baseUrl}/verificacion/enviar-codigo'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'telefono': telefono}),
    );

    if (respuesta.statusCode != 200) {
      throw Exception(ApiClient.mensajeDeError(respuesta, 'No se pudo enviar el código de verificación.'));
    }

    final data = jsonDecode(utf8.decode(respuesta.bodyBytes));
    return {
      'smsEnviado': data['smsEnviado'] ?? true,
      'codigoDesarrollo': data['codigoDesarrollo'],
    };
  }

  Future<void> confirmarCodigo(String telefono, String codigo) async {
    final respuesta = await ApiClient.post(
      Uri.parse('${ApiConfig.baseUrl}/verificacion/confirmar-codigo'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'telefono': telefono, 'codigo': codigo}),
    );

    if (respuesta.statusCode != 200) {
      throw Exception(ApiClient.mensajeDeError(respuesta, 'No se pudo verificar el código.'));
    }
  }
}
