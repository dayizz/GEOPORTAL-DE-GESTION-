import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';

/// Dibuja una figura (`TipoFigura`) dentro de su caja delimitadora,
/// respetando color de trazo/grosor/relleno, [estiloLinea] (continua,
/// segmentada, punteada o línea-punto) y, para [TipoFigura.linea], una
/// punta decorativa ([puntaTipo]: flecha o punto) en el extremo
/// izquierdo ([puntaIzquierda]) y/o derecho ([puntaDerecha]).
class ShapePainter extends CustomPainter {
  ShapePainter({
    required this.figuraTipo,
    required this.colorTrazo,
    required this.grosorTrazo,
    required this.colorRelleno,
    this.estiloLinea = EstiloLinea.continua,
    this.espaciadoLinea = 1,
    this.puntaTipo = TipoPuntaLinea.ninguna,
    this.puntaTamano = 10,
    this.puntaIzquierda = false,
    this.puntaDerecha = false,
  });

  final TipoFigura figuraTipo;
  final Color colorTrazo;
  final double grosorTrazo;
  final Color? colorRelleno;
  final EstiloLinea estiloLinea;
  final double espaciadoLinea;
  final TipoPuntaLinea puntaTipo;
  final double puntaTamano;
  final bool puntaIzquierda;
  final bool puntaDerecha;

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
      ..style = PaintingStyle.stroke
      ..strokeCap = estiloLinea == EstiloLinea.continua ? StrokeCap.butt : StrokeCap.round;
    final rellenoPaint = colorRelleno != null
        ? (Paint()
          ..color = colorRelleno!
          ..style = PaintingStyle.fill)
        : null;

    Path contorno;
    switch (figuraTipo) {
      case TipoFigura.rectangulo:
      case TipoFigura.cuadrado:
        contorno = Path()..addRect(Offset.zero & size);
      case TipoFigura.triangulo:
      case TipoFigura.hexagono:
      case TipoFigura.pentagono:
        final lados = switch (figuraTipo) {
          TipoFigura.triangulo => 3,
          TipoFigura.pentagono => 5,
          _ => 6,
        };
        contorno = Path()..addPolygon(_poligonoRegular(size, lados), true);
      case TipoFigura.linea:
        final y = size.height / 2;
        contorno = Path()
          ..moveTo(0, y)
          ..lineTo(size.width, y);
    }

    if (rellenoPaint != null) canvas.drawPath(contorno, rellenoPaint);
    canvas.drawPath(
      estiloLineaDe(contorno, estiloLinea, grosorTrazo, espaciadoLinea),
      trazoPaint,
    );

    if (figuraTipo == TipoFigura.linea && puntaTipo != TipoPuntaLinea.ninguna) {
      final y = size.height / 2;
      final puntaPaint = Paint()
        ..color = colorTrazo
        ..style = PaintingStyle.fill;
      if (puntaIzquierda) {
        dibujarPuntaLinea(canvas, puntaPaint, Offset(0, y), const Offset(-1, 0), puntaTipo, puntaTamano);
      }
      if (puntaDerecha) {
        dibujarPuntaLinea(canvas, puntaPaint, Offset(size.width, y), const Offset(1, 0), puntaTipo, puntaTamano);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return oldDelegate.figuraTipo != figuraTipo ||
        oldDelegate.colorTrazo != colorTrazo ||
        oldDelegate.grosorTrazo != grosorTrazo ||
        oldDelegate.colorRelleno != colorRelleno ||
        oldDelegate.estiloLinea != estiloLinea ||
        oldDelegate.espaciadoLinea != espaciadoLinea ||
        oldDelegate.puntaTipo != puntaTipo ||
        oldDelegate.puntaTamano != puntaTamano ||
        oldDelegate.puntaIzquierda != puntaIzquierda ||
        oldDelegate.puntaDerecha != puntaDerecha;
  }
}

/// Patrón segmentado (largo de trazo/espacio, en múltiplos de [grosor] y
/// escalado por [espaciado]) para cada [EstiloLinea]. `null` para
/// "continua" -no requiere partir el path. El segmento casi-cero de
/// "punteada"/"línea-punto" (que no se escala, para conservar el punto
/// como un punto y no un trazo) produce un punto redondo gracias a
/// `strokeCap: round` del [Paint] que lo pinta.
List<double>? _patronDe(EstiloLinea estilo, double grosor, double espaciado) {
  switch (estilo) {
    case EstiloLinea.continua:
      return null;
    case EstiloLinea.segmentada:
      return [grosor * 3 * espaciado, grosor * 2 * espaciado];
    case EstiloLinea.punteada:
      return [0.01, grosor * 2.2 * espaciado];
    case EstiloLinea.lineaPunto:
      return [grosor * 3 * espaciado, grosor * 1.6 * espaciado, 0.01, grosor * 1.6 * espaciado];
  }
}

/// Convierte [origen] en un path punteado/segmentado según [estilo],
/// recorriendo cada contorno con `PathMetrics` -funciona igual para una
/// línea recta que para el contorno de un rectángulo o polígono.
/// [espaciado] escala la separación entre trazos/puntos (1 = tamaño por
/// defecto).
Path estiloLineaDe(Path origen, EstiloLinea estilo, double grosor, [double espaciado = 1]) {
  final patron = _patronDe(estilo, grosor, espaciado);
  if (patron == null) return origen;

  final destino = Path();
  for (final metric in origen.computeMetrics()) {
    var distancia = 0.0;
    var dibujar = true;
    var indice = 0;
    while (distancia < metric.length) {
      final largo = patron[indice % patron.length];
      final siguiente = math.min(distancia + largo, metric.length);
      if (dibujar) {
        destino.addPath(metric.extractPath(distancia, siguiente), Offset.zero);
      }
      distancia = siguiente;
      dibujar = !dibujar;
      indice++;
    }
  }
  return destino;
}

/// Dibuja una punta (flecha o punto) en [punto], apuntando hacia
/// [direccion] (vector unitario que se alcanza hacia afuera del cuerpo de
/// la línea) con tamaño [tamano]. Usada tanto por [ShapePainter] como por
/// la vista previa del selector de puntas en el panel de propiedades.
void dibujarPuntaLinea(
  Canvas canvas,
  Paint paint,
  Offset punto,
  Offset direccion,
  TipoPuntaLinea tipo,
  double tamano,
) {
  switch (tipo) {
    case TipoPuntaLinea.ninguna:
      return;
    case TipoPuntaLinea.punto:
      canvas.drawCircle(punto, tamano / 2, paint);
    case TipoPuntaLinea.flecha:
      const apertura = math.pi / 7;
      final angulo = math.atan2(direccion.dy, direccion.dx) + math.pi;
      final p1 = punto +
          Offset(math.cos(angulo - apertura), math.sin(angulo - apertura)) * tamano;
      final p2 = punto +
          Offset(math.cos(angulo + apertura), math.sin(angulo + apertura)) * tamano;
      final path = Path()
        ..moveTo(punto.dx, punto.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(path, paint);
  }
}
