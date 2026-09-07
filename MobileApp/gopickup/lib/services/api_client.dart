import 'dart:async';
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
}
