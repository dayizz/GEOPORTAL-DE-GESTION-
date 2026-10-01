import 'package:flutter/material.dart';

/// Marca en forma de "x" delgada que se dibuja momentáneamente sobre el
/// punto de referencia (esquina o línea media de la hoja) cuando OSNAP
/// imanta un elemento durante un arrastre/redimensionado -ver
/// `ElementoBox._reportarSnap` y el `onSnapIndicador` que la reporta-.
/// Puramente visual: no captura gestos.
class SnapIndicator extends StatelessWidget {
  const SnapIndicator({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(size, size),
        painter: _SnapXPainter(),
      ),
    );
  }
}

class _SnapXPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _SnapXPainter oldDelegate) => false;
}
