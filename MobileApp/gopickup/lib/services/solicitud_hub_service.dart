import 'dart:async';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import '../config/api_config.dart';
import '../models/solicitud.dart';

class MensajeChat {
  final String remitente; // "cliente" o "conductor"
  final String texto;
  final DateTime fecha;

  MensajeChat({required this.remitente, required this.texto, required this.fecha});
}

class SolicitudHubService {
  final String token;
  HubConnection? _conexion;

  // Los mensajes de chat se retransmiten por este stream sin importar si en
  // el momento de conectar (conectarYUnirse) ya existía o no una pantalla de
  // chat abierta escuchando. Antes el listener de 'mensajeChatRecibido' solo
  // se registraba si se pasaba el callback alRecibirMensajeChat, pero las
  // pantallas que abren la conexión (SolicitudEnCursoScreen /
  // ServicioEnCursoConductorScreen) nunca lo pasaban -- por eso el chat nunca
  // mostraba los mensajes entrantes. Ahora el hub siempre escucha el evento y
  // lo publica aquí; la pantalla de chat se suscribe cuando se abre.
  final _mensajesChatController = StreamController<MensajeChat>.broadcast();
  Stream<MensajeChat> get mensajesChat => _mensajesChatController.stream;

  // Aviso en tiempo real de que el conductor ya llegó al punto de recogida
  // (ver ConductoresController.ActualizarUbicacion en el backend).
  final _conductorLlegoController = StreamController<void>.broadcast();
  Stream<void> get conductorLlego => _conductorLlegoController.stream;

  SolicitudHubService(this.token);

  Future<void> conectarYUnirse({
    required int solicitudId,
    required void Function(Solicitud solicitud) alActualizarSolicitud,
    required void Function(double lat, double lng) alActualizarUbicacion,
  }) async {
    _conexion = HubConnectionBuilder()
        .withUrl('${ApiConfig.hubUrl}?access_token=$token')
        .withAutomaticReconnect()
        .build();

    _conexion!.on('solicitudActualizada', (args) {
      if (args != null && args.isNotEmpty) {
        alActualizarSolicitud(Solicitud.fromJson(args[0] as Map<String, dynamic>));
      }
    });

    _conexion!.on('ubicacionConductorActualizada', (args) {
      if (args != null && args.length >= 2) {
        alActualizarUbicacion(args[0] as double, args[1] as double);
      }
    });

    _conexion!.on('mensajeChatRecibido', (args) {
      if (args != null && args.length >= 3) {
        _mensajesChatController.add(MensajeChat(
          remitente: args[0] as String,
          texto: args[1] as String,
          fecha: DateTime.tryParse(args[2] as String) ?? DateTime.now(),
        ));
      }
    });

    _conexion!.on('conductorLlegoAlPunto', (_) {
      _conductorLlegoController.add(null);
    });

    await _conexion!.start();
    await _conexion!.invoke('UnirseASolicitud', args: [solicitudId]);
  }

  Future<void> conectarComoConductorDisponible({
    required void Function(Solicitud solicitud) alLlegarNuevaSolicitud,
  }) async {
    _conexion = HubConnectionBuilder()
        .withUrl('${ApiConfig.hubUrl}?access_token=$token')
        .withAutomaticReconnect()
        .build();

    _conexion!.onreconnected(({connectionId}) async {
      await _conexion!.invoke('UnirseComoConductorDisponible');
    });

    _conexion!.on('nuevaSolicitudDisponible', (args) {
      if (args != null && args.isNotEmpty) {
        alLlegarNuevaSolicitud(Solicitud.fromJson(args[0] as Map<String, dynamic>));
      }
    });

    await _conexion!.start();
    await _conexion!.invoke('UnirseComoConductorDisponible');
  }

  Future<void> enviarUbicacion(int solicitudId, double lat, double lng) async {
    if (_conexion == null) return;
    try {
      await _conexion!.invoke('EnviarUbicacionConductor', args: [solicitudId, lat, lng]);
    } catch (_) {}
  }

  // Chat interno: el mensaje solo se retransmite en vivo, nunca se guarda.
  Future<void> enviarMensajeChat(int solicitudId, String remitente, String mensaje) async {
    if (_conexion == null) return;
    try {
      await _conexion!.invoke('EnviarMensajeChat', args: [solicitudId, remitente, mensaje]);
    } catch (_) {}
  }

  Future<void> desconectar() async {
    try {
      await _conexion?.invoke('SalirComoConductorDisponible');
    } catch (_) {}
    await _conexion?.stop();
  }

  void dispose() {
    _mensajesChatController.close();
    _conductorLlegoController.close();
  }
}
