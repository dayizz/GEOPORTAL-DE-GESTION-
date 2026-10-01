import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';

/// Recorta el contenido de una ventana de mapa según [FormaMarco]. La
/// caja delimitadora (selección, manijas de redimensionar) permanece
/// rectangular; solo el mapa renderizado dentro se recorta.
class MarcoClipper extends CustomClipper<Path> {
  const MarcoClipper(this.figura);

  final FormaMarco figura;

  List<Offset> _poligonoRegular(Size size, int lados) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width / 2;
    final ry = size.height / 2;
    return List.generate(lados, (i) {
      final angulo = -math.pi / 2 + (2 * math.pi * i / lados);
      return Offset(cx + rx * math.cos(angulo), cy + ry * math.sin(angulo));
    });
  }

  @override
  Path getClip(Size size) {
    switch (figura) {
      case FormaMarco.cuadrada:
        return Path()..addRect(Offset.zero & size);
      case FormaMarco.circular:
        return Path()..addOval(Offset.zero & size);
      case FormaMarco.triangular:
        return Path()..addPolygon(_poligonoRegular(size, 3), true);
      case FormaMarco.hexagonal:
        return Path()..addPolygon(_poligonoRegular(size, 6), true);
    }
  }

  @override
  bool shouldReclip(covariant MarcoClipper oldClipper) => oldClipper.figura != figura;
}

/// Dibuja el borde del marco de una ventana de mapa, siguiendo el mismo
/// contorno que recorta [MarcoClipper] (para que el trazo calce
/// exactamente con la forma visible del mapa).
class MarcoBorderPainter extends CustomPainter {
  const MarcoBorderPainter({
    required this.figura,
    required this.color,
    required this.grosor,
  });

  final FormaMarco figura;
  final Color color;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      MarcoClipper(figura).getClip(size),
      Paint()
        ..color = color
        ..strokeWidth = grosor
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant MarcoBorderPainter oldDelegate) =>
      oldDelegate.figura != figura || oldDelegate.color != color || oldDelegate.grosor != grosor;
}
