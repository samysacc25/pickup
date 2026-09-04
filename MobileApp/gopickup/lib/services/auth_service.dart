import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/usuario.dart';
import '../models/solicitud.dart';
import '../models/licencia.dart';

class AuthService {
  Future<SesionUsuario> registrarCliente({
    required String nombreCompleto,
    required String correo,
    required String telefono,
    required String clave,
  }) async {
    final respuesta = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/registro/cliente'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombreCompleto': nombreCompleto,
        'correo': correo,
        'telefono': telefono,
        'clave': clave,
      }),
    );
    return _procesarRespuestaAuth(respuesta);
  }

  Future<SesionUsuario> solicitarSerConductor({
    required String nombreCompleto,
    required String correo,
    required String telefono,
    required String clave,
    required String numeroCedula,
    required TipoLicencia tipoLicencia,
    required String placa,
    required String marca,
    required String modelo,
    required String color,
    required int anio,
    required TipoCamioneta tipoCamioneta,
    String? descripcionCapacidad,
  }) async {
    final respuesta = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/registro/conductor'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombreCompleto': nombreCompleto,
        'correo': correo,
        'telefono': telefono,
        'clave': clave,
        'numeroCedula': numeroCedula,
        'tipoLicencia': tipoLicenciaANumero(tipoLicencia),
        'placa': placa,
        'marca': marca,
        'modelo': modelo,
        'color': color,
        'anio': anio,
        'tipoCamioneta': tipoCamionetaANumero(tipoCamioneta),
        'descripcionCapacidad': descripcionCapacidad,
      }),
    );
    return _procesarRespuestaAuth(respuesta);
  }

  Future<SesionUsuario> iniciarSesion({required String correo, required String clave}) async {
    final respuesta = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'clave': clave}),
    );
    return _procesarRespuestaAuth(respuesta);
  }

  Future<SesionUsuario> _procesarRespuestaAuth(http.Response respuesta) async {
    if (respuesta.statusCode == 200) {
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
      final sesion = SesionUsuario.fromJson(json);
      await _guardarSesion(sesion);
      return sesion;
    }
    final error = jsonDecode(utf8.decode(respuesta.bodyBytes));
    throw Exception(error['mensaje'] ?? 'No se pudo completar la operación.');
  }

  Future<void> _guardarSesion(SesionUsuario sesion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sesion', jsonEncode(sesion.toJson()));
  }

  Future<SesionUsuario?> obtenerSesionGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('sesion');
    if (data == null) return null;
    return SesionUsuario.fromJson(jsonDecode(data));
  }

  Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sesion');
  }
}
