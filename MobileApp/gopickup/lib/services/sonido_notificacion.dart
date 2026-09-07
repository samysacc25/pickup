import 'package:audioplayers/audioplayers.dart';

// Sonido corto que se reproduce junto con las notificaciones importantes
// (nueva solicitud para el conductor, actualizaciones de viaje para el
// cliente) -- antes las notificaciones en primer plano solo mostraban un
// SnackBar silencioso. Se usa una única instancia de AudioPlayer para toda
// la app en vez de crear una por cada notificación.
class SonidoNotificacion {
  static final AudioPlayer _reproductor = AudioPlayer();

  static Future<void> reproducir() async {
    try {
      await _reproductor.stop();
      await _reproductor.play(AssetSource('sounds/notificacion.wav'), volume: 1.0);
    } catch (_) {
      // Si el dispositivo está en silencio, no hay audio inicializado, etc.
      // no debe interrumpir el flujo de la app por esto.
    }
  }
}
