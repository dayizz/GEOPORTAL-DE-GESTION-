import 'package:flutter/material.dart';

/// Flecha de norte simple (apunta "arriba" por defecto). La rotación para
/// orientarla se maneja igual que cualquier otro elemento, vía el campo
/// `rotacion` genérico de [ElementoComposicion] (ver panel de
/// propiedades), no es un estado propio de este widget.
class NorteWidget extends StatelessWidget {
  const NorteWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _NortePainter(),
    );
  }
}

class _NortePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final trazo = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    final altoFlecha = size.height * 0.62;
    final anchoFlecha = size.width * 0.5;
    final baseY = size.height * 0.92;
    final puntaY = baseY - altoFlecha;

    final path = Path()
      ..moveTo(cx, puntaY)
      ..lineTo(cx + anchoFlecha / 2, baseY)
      ..lineTo(cx, baseY - altoFlecha * 0.25)
      ..lineTo(cx - anchoFlecha / 2, baseY)
      ..close();
    canvas.drawPath(path, trazo);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
