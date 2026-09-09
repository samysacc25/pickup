import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Envoltorio delgado sobre `http` que agrega un tiempo de espera razonable a
// cada llamada al backend. Antes ninguna petición tenía timeout, así que si
// el servidor se demoraba (por ejemplo Azure "despertando" de un cold start,
// o mala señal), la pantalla se quedaba cargando indefinidamente sin ningún
// mensaje. Ahora, pasado el límite, se lanza un error claro que las pantallas
// ya saben mostrar con mostrarError().
class ApiClient {
  static const Duration _tiempoLimite = Duration(seconds: 20);

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    return http.get(url, headers: headers).timeout(_tiempoLimite, onTimeout: _agotado);
  }

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) {
    return http.post(url, headers: headers, body: body).timeout(_tiempoLimite, onTimeout: _agotado);
  }

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) {
    return http.put(url, headers: headers, body: body).timeout(_tiempoLimite, onTimeout: _agotado);
  }

  static Never _agotado() {
    throw Exception('El servidor está tardando en responder. Intenta de nuevo en unos segundos.');
  }

  // Extrae el mensaje de error de una respuesta que se supone trae
  // {"mensaje": "..."} en JSON. Antes cada servicio hacía su propio
  // jsonDecode(respuesta.bodyBytes) sobre el cuerpo del error, y si el
  // servidor respondía con el cuerpo vacío o algo que no era JSON (por
  // ejemplo una página de error de Azure mientras el servicio se está
  // reiniciando), eso reventaba con un FormatException feo en vez de
  // mostrar un aviso entendible. Ahora, si no se puede leer el mensaje,
  // se usa uno genérico en su lugar.
  static String mensajeDeError(http.Response respuesta, [String porDefecto = 'Ocurrió un error. Intenta de nuevo.']) {
    try {
      final cuerpo = utf8.decode(respuesta.bodyBytes);
      if (cuerpo.trim().isEmpty) return porDefecto;
      final data = jsonDecode(cuerpo);
      if (data is Map && data['mensaje'] != null) return data['mensaje'].toString();
      return porDefecto;
    } catch (_) {
      return porDefecto;
    }
  }
}
