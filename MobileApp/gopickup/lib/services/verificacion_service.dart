import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class VerificacionService {
  Future<Map<String, dynamic>> enviarCodigo(String telefono) async {
    final respuesta = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/verificacion/enviar-codigo'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'telefono': telefono}),
    );

    final data = jsonDecode(utf8.decode(respuesta.bodyBytes));

    if (respuesta.statusCode != 200) {
      throw Exception(data['mensaje'] ?? 'No se pudo enviar el código de verificación.');
    }

    return {
      'smsEnviado': data['smsEnviado'] ?? true,
      'codigoDesarrollo': data['codigoDesarrollo'],
    };
  }

  Future<void> confirmarCodigo(String telefono, String codigo) async {
    final respuesta = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/verificacion/confirmar-codigo'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'telefono': telefono, 'codigo': codigo}),
    );

    if (respuesta.statusCode != 200) {
      final data = jsonDecode(utf8.decode(respuesta.bodyBytes));
      throw Exception(data['mensaje'] ?? 'No se pudo verificar el código.');
    }
  }
}
