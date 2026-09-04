import 'package:flutter/material.dart';

class Responsive {
  final BuildContext context;
  late final Size _size;

  Responsive(this.context) {
    _size = MediaQuery.of(context).size;
  }

  double get anchoPantalla => _size.width;
  double get altoPantalla => _size.height;
  bool get esTablet => anchoPantalla >= 600;
  double ancho(double porcentaje) => anchoPantalla * porcentaje;
  double alto(double porcentaje) => altoPantalla * porcentaje;

  double fuente(double base) {
    final factor = anchoPantalla / 390;
    final resultado = base * factor;
    return resultado.clamp(base * 0.85, base * 1.3);
  }

  EdgeInsets get paddingHorizontal => EdgeInsets.symmetric(
        horizontal: esTablet ? anchoPantalla * 0.12 : 20,
      );

  double get anchoMaximoFormulario => esTablet ? 480 : anchoPantalla;
}

extension ResponsiveExtension on BuildContext {
  Responsive get responsive => Responsive(this);
}

class ContenedorResponsivo extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const ContenedorResponsivo({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.anchoMaximoFormulario),
        child: Padding(
          padding: padding ?? r.paddingHorizontal,
          child: child,
        ),
      ),
    );
  }
}
