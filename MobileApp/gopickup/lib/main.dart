import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'theme/go_pickup_theme.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(manejadorMensajesEnSegundoPlano);
  } catch (_) {}

  runApp(const GoPickupApp());
}

class GoPickupApp extends StatelessWidget {
  const GoPickupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Go Pickup',
      debugShowCheckedModeBanner: false,
      theme: GoPickupTheme.tema,
      home: const SplashScreen(),
    );
  }
}
