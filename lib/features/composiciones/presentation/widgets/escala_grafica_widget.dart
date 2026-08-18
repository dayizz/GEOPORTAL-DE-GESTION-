import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Escala gráfica derivada del zoom/latitud de un elemento de mapa
/// asociado. `metrosPorMm` ya viene calculado por quien llama (a partir
/// del zoom+latitud del mapa y la escala de render px/mm vigente -ver
/// `elemento_contenido.dart`-, fórmula estándar de Web Mercator:
/// metros/px = 156543.03392 * cos(lat) / 2^zoom).
class EscalaGraficaWidget extends StatelessWidget {
  const EscalaGraficaWidget({
    super.key,
    required this.metrosPorMm,
    required this.anchoDisponibleMm,
  });

  final double? metrosPorMm;
  final double anchoDisponibleMm;

  /// Distancia "redonda" (1/2/5 × 10^n) más grande que cabe en
  /// [anchoMaxMm] dado [metrosPorMm].
  static double _distanciaLinda(double metrosPorMm, double anchoMaxMm) {
    final maxMetros = metrosPorMm * anchoMaxMm;
    if (maxMetros <= 0) return 1;
    const pasos = [1, 2, 5];
    var mejor = 1.0;
    for (var exp = -2; exp <= 7; exp++) {
      for (final p in pasos) {
        final candidato = p * math.pow(10, exp);
        if (candidato <= maxMetros && candidato > mejor) mejor = candidato.toDouble();
      }
    }
    return mejor;
  }

  static String _etiqueta(double metros) {
    if (metros >= 1000) {
      final km = metros / 1000;
      return '${km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toStringAsFixed(1)} km';
    }
    return '${metros.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    final mpm = metrosPorMm;
    if (mpm == null || mpm <= 0) {
      return Container(
        alignment: Alignment.centerLeft,
        child: const Text(
          'Escala: sin mapa asociado',
          style: TextStyle(fontSize: 9, color: Colors.black54, fontStyle: FontStyle.italic),
        ),
      );
    }

    final anchoMaxMm = math.max(10, anchoDisponibleMm - 4).toDouble();
    final distanciaM = _distanciaLinda(mpm, anchoMaxMm);
    final barraMm = (distanciaM / mpm).clamp(8, anchoDisponibleMm);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: barraMm.toDouble(),
          height: 10,
          child: CustomPaint(painter: _EscalaBarraPainter()),
        ),
        const SizedBox(height: 2),
        Text(_etiqueta(distanciaM), style: const TextStyle(fontSize: 9, color: Colors.black87)),
      ],
    );
  }
}

class _EscalaBarraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.4;
    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    for (final x in [0.0, size.width / 2, size.width]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
