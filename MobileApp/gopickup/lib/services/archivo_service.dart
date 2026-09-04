import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class ArchivoService {
  final String token;
  ArchivoService(this.token);

  Future<void> subirFotoPerfil(File foto) async {
    await _subir(uri: Uri.parse('${ApiConfig.baseUrl}/archivos/foto-perfil'), foto: foto);
  }

  // tipo: 'lateral' | 'frontal' | 'cabina'
  Future<void> subirFotoVehiculo(File foto, String tipo) async {
    await _subir(uri: Uri.parse('${ApiConfig.baseUrl}/archivos/foto-vehiculo?tipo=$tipo'), foto: foto);
  }

  // Foto frontal de la licencia de conducir del conductor.
  Future<void> subirFotoLicencia(File foto) async {
    await _subir(uri: Uri.parse('${ApiConfig.baseUrl}/archivos/foto-licencia'), foto: foto);
  }

  Future<void> _subir({required Uri uri, required File foto}) async {
    try {
      final peticion = http.MultipartRequest('POST', uri);
      peticion.headers['Authorization'] = 'Bearer $token';
      peticion.files.add(await http.MultipartFile.fromPath('foto', foto.path));

      final respuestaStream = await peticion.send().timeout(const Duration(minutes: 3));
      final respuesta = await http.Response.fromStream(respuestaStream);

      if (respuesta.statusCode != 200) {
        String mensaje = 'No se pudo subir la foto. Intenta de nuevo.';
        try {
          final error = jsonDecode(utf8.decode(respuesta.bodyBytes));
          mensaje = error['mensaje'] ?? mensaje;
        } catch (_) {}
        throw Exception(mensaje);
      }
    } on SocketException {
      throw Exception('No hay conexión con el servidor. Verifica tu internet e intenta de nuevo.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Ocurrió un problema al subir la foto. Intenta de nuevo.');
    }
  }
}
