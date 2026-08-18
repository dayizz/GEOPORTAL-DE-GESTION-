import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';

/// Dibuja una figura (`TipoFigura`) dentro de su caja delimitadora,
/// respetando color de trazo/grosor/relleno del elemento.
class ShapePainter extends CustomPainter {
  ShapePainter({
    required this.figuraTipo,
    required this.colorTrazo,
    required this.grosorTrazo,
    required this.colorRelleno,
  });

  final TipoFigura figuraTipo;
  final Color colorTrazo;
  final double grosorTrazo;
  final Color? colorRelleno;

  List<Offset> _poligonoRegular(Size size, int lados, {double rotacionInicial = -math.pi / 2}) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width / 2;
    final ry = size.height / 2;
    return List.generate(lados, (i) {
      final angulo = rotacionInicial + (2 * math.pi * i / lados);
      return Offset(cx + rx * math.cos(angulo), cy + ry * math.sin(angulo));
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final trazoPaint = Paint()
      ..color = colorTrazo
      ..strokeWidth = grosorTrazo
      ..style = PaintingStyle.stroke;
    final rellenoPaint = colorRelleno != null
        ? (Paint()
          ..color = colorRelleno!
          ..style = PaintingStyle.fill)
        : null;

    switch (figuraTipo) {
      case TipoFigura.rectangulo:
      case TipoFigura.cuadrado:
        final rect = Offset.zero & size;
        if (rellenoPaint != null) canvas.drawRect(rect, rellenoPaint);
        canvas.drawRect(rect, trazoPaint);
        break;
      case TipoFigura.triangulo:
      case TipoFigura.hexagono:
      case TipoFigura.pentagono:
        final lados = switch (figuraTipo) {
          TipoFigura.triangulo => 3,
          TipoFigura.pentagono => 5,
          _ => 6,
        };
        final puntos = _poligonoRegular(size, lados);
        final path = Path()..addPolygon(puntos, true);
        if (rellenoPaint != null) canvas.drawPath(path, rellenoPaint);
        canvas.drawPath(path, trazoPaint);
        break;
      case TipoFigura.linea:
      case TipoFigura.lineaPunteada:
        final y = size.height / 2;
        final start = Offset(0, y);
        final end = Offset(size.width, y);
        if (figuraTipo == TipoFigura.linea) {
          canvas.drawLine(start, end, trazoPaint);
        } else {
          _drawDashedLine(canvas, start, end, trazoPaint);
        }
        break;
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 5.0;
    final total = (end - start).distance;
    if (total <= 0) return;
    final direction = (end - start) / total;
    var distance = 0.0;
    while (distance < total) {
      final segmentEnd = math.min(distance + dashWidth, total);
      canvas.drawLine(start + direction * distance, start + direction * segmentEnd, paint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return oldDelegate.figuraTipo != figuraTipo ||
        oldDelegate.colorTrazo != colorTrazo ||
        oldDelegate.grosorTrazo != grosorTrazo ||
        oldDelegate.colorRelleno != colorRelleno;
  }
}
