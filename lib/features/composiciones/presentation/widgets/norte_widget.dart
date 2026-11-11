import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';

/// Flecha de norte (apunta "arriba" por defecto) en uno de los diseños de
/// [TipoNorte]. La orientación manual usa el campo `rotacion` genérico del
/// elemento; [rotacion] (grados, horario) es un giro adicional para seguir
/// la orientación de un mapa (ver `norteMapaId`).
class NorteWidget extends StatelessWidget {
  const NorteWidget({
    super.key,
    this.tipo = TipoNorte.flecha,
    this.color = Colors.black87,
    this.rotacion = 0,
  });
  final TipoNorte tipo;
  final Color color;
  final double rotacion;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotacion * math.pi / 180,
      child: CustomPaint(
        size: Size.infinite,
        painter: NortePainter(tipo: tipo, color: color),
      ),
    );
  }
}

/// Dibuja el norte en un espacio de diseño de 100×125 (la "N" ocupa la
/// franja superior de 25) escalado uniformemente y centrado en [size].
/// Público para la vista previa de diseños en el panel de propiedades.
class NortePainter extends CustomPainter {
  NortePainter({required this.tipo, required this.color});
  final TipoNorte tipo;
  final Color color;

  static const _ancho = 100.0;
  static const _alto = 125.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final escala = math.min(size.width / _ancho, size.height / _alto);
    canvas.save();
    canvas.translate((size.width - _ancho * escala) / 2, (size.height - _alto * escala) / 2);
    canvas.scale(escala);

    final relleno = Paint()..color = color;
    final contorno = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;

    switch (tipo) {
      case TipoNorte.flecha:
        canvas.drawPath(_poligono([(50, 30), (75, 120), (50, 98), (25, 120)]), relleno);
      case TipoNorte.mediaFlecha:
        canvas.drawPath(_poligono([(50, 30), (24, 120), (50, 104)]), relleno);
        canvas.drawPath(_poligono([(50, 30), (76, 120), (50, 104), (24, 120)]), contorno);
      case TipoNorte.rosa:
        _rosa(canvas, relleno, contorno);
      case TipoNorte.circulo:
        canvas.drawCircle(const Offset(50, 78), 42, contorno);
        canvas.drawPath(_poligono([(50, 42), (67, 106), (50, 92), (33, 106)]), relleno);
    }

    final n = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    n.paint(canvas, Offset(50 - n.width / 2, 2));
    n.dispose();
    canvas.restore();
  }

  /// Rosa de los vientos de 4 puntas: cada punta es mitad rellena y mitad
  /// contorno; las diagonales, más cortas, solo en contorno.
  void _rosa(Canvas canvas, Paint relleno, Paint contorno) {
    const c = Offset(50, 78);
    Offset punto(double grados, double radio) {
      final r = grados * math.pi / 180;
      return c + Offset(math.sin(r) * radio, -math.cos(r) * radio);
    }

    final delgado = Paint()
      ..color = contorno.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    for (final g in [45.0, 135.0, 225.0, 315.0]) {
      canvas.drawPath(
        _poligonoOffsets([c, punto(g - 20, 10), punto(g, 26), punto(g + 20, 10)]),
        delgado,
      );
    }
    for (final g in [0.0, 90.0, 180.0, 270.0]) {
      final punta = punto(g, 46);
      final izq = punto(g - 45, 15);
      final der = punto(g + 45, 15);
      canvas.drawPath(_poligonoOffsets([c, izq, punta]), relleno);
      canvas.drawPath(_poligonoOffsets([c, punta, der]), delgado);
    }
  }

  Path _poligono(List<(double, double)> puntos) =>
      _poligonoOffsets([for (final (x, y) in puntos) Offset(x, y)]);

  Path _poligonoOffsets(List<Offset> puntos) {
    final path = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final p in puntos.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(NortePainter old) => old.tipo != tipo || old.color != color;
}
