import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/go_pickup_theme.dart';
import '../../theme/responsive.dart';
import '../../models/usuario.dart';
import '../../models/solicitud.dart';
import '../../services/solicitud_service.dart';

class HistorialClienteScreen extends StatefulWidget {
  final SesionUsuario sesion;
  const HistorialClienteScreen({super.key, required this.sesion});

  @override
  State<HistorialClienteScreen> createState() => _HistorialClienteScreenState();
}

class _HistorialClienteScreenState extends State<HistorialClienteScreen> {
  late final SolicitudService _solicitudService;
  late Future<List<Solicitud>> _futuroSolicitudes;

  @override
  void initState() {
    super.initState();
    _solicitudService = SolicitudService(widget.sesion.token);
    _futuroSolicitudes = _solicitudService.misSolicitudes();
  }

  Color _colorEstado(EstadoSolicitud estado) {
    switch (estado) {
      case EstadoSolicitud.finalizada:
        return GoPickupColors.verde;
      case EstadoSolicitud.canceladaCliente:
      case EstadoSolicitud.canceladaConductor:
      case EstadoSolicitud.sinConductores:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de viajes')),
      body: FutureBuilder<List<Solicitud>>(
        future: _futuroSolicitudes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo cargar el historial.'));
          }

          final solicitudes = snapshot.data ?? [];
          if (solicitudes.isEmpty) {
            return const Center(child: Text('Todavía no tienes viajes registrados.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: solicitudes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final s = solicitudes[index];
              final tarifa = s.tarifaFinal ?? s.tarifaAcordada ?? s.tarifaSugerida;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatoFecha.format(s.fechaSolicitud.toLocal()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: _colorEstado(s.estado).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text(textoEstado(s.estado), style: TextStyle(color: _colorEstado(s.estado), fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(s.llevaCarga ? (s.descripcionCarga ?? 'Con carga adicional') : 'Transporte de pasajero', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.circle, size: 10, color: GoPickupColors.verde),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s.origenDireccion, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                      Row(children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.red),
                        const SizedBox(width: 6),
                        Expanded(child: Text(s.destinoDireccion, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 10),
                      Text('\$${tarifa.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.responsive.fuente(16), color: GoPickupColors.verdeOscuro)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
