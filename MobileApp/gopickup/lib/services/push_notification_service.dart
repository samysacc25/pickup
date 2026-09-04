import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../widgets/notificacion.dart';

class PushNotificationService {
  static final PushNotificationService _instancia = PushNotificationService._interno();
  factory PushNotificationService() => _instancia;
  PushNotificationService._interno();

  final FirebaseMessaging _mensajeria = FirebaseMessaging.instance;

  Future<void> inicializar({required String token, required BuildContext context}) async {
    try {
      await _mensajeria.requestPermission(alert: true, badge: true, sound: true);

      final tokenDispositivo = await _mensajeria.getToken();
      if (tokenDispositivo != null) {
        await _enviarTokenAlBackend(token, tokenDispositivo);
      }

      _mensajeria.onTokenRefresh.listen((nuevoToken) => _enviarTokenAlBackend(token, nuevoToken));

      FirebaseMessaging.onMessage.listen((mensaje) {
        if (!context.mounted) return;
        final titulo = mensaje.notification?.title ?? 'Go Pickup';
        final cuerpo = mensaje.notification?.body ?? '';
        mostrarExito(context, '$titulo: $cuerpo');
      });
    } catch (_) {}
  }

  Future<void> _enviarTokenAlBackend(String tokenSesion, String tokenDispositivo) async {
    try {
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/notificaciones/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSesion',
        },
        body: jsonEncode({'token': tokenDispositivo}),
      );
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> manejadorMensajesEnSegundoPlano(RemoteMessage mensaje) async {}
