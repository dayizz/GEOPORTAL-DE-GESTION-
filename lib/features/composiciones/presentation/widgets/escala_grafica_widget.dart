import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';

/// Escala gráfica derivada del zoom/latitud de un elemento de mapa
/// asociado. `metrosPorPx` ya viene calculado por quien llama (ver
/// `elemento_contenido.dart`, fórmula estándar de Web Mercator:
/// metros/px = 156543.03392 * cos(lat) / 2^zoom). Como el mapa se dibuja a
/// 1 px de tile por px de render, la barra se mide en esos mismos px.
class EscalaGraficaWidget extends StatelessWidget {
  const EscalaGraficaWidget({
    super.key,
    required this.metrosPorPx,
    this.tipo = TipoEscala.linea,
    this.color = Colors.black87,
    this.grosor = 1.4,
    this.ancho = 6,
    this.divisiones = 2,
    this.onTamano,
  });

  final double? metrosPorPx;
  final TipoEscala tipo;
  final Color color;
  final double grosor;
  final double ancho;
  final int divisiones;
  /// Recibe (después del frame) el tamaño en px que ocupa la escala para el
  /// ancho disponible, para que el editor ajuste el recuadro a ella.
  final ValueChanged<Size>? onTamano;

  @override
  Widget build(BuildContext context) {
    final mpp = metrosPorPx;
    if (mpp == null || mpp <= 0) {
      return Container(
        alignment: Alignment.centerLeft,
        child: const Text(
          'Escala: sin mapa asociado',
          style: TextStyle(fontSize: 9, color: Colors.black54, fontStyle: FontStyle.italic),
        ),
      );
    }
    final painter = _EscalaPainter(
      metrosPorPx: mpp,
      tipo: tipo,
      color: color,
      grosor: grosor,
      ancho: ancho,
      divisiones: divisiones.clamp(1, 10),
    );
    final onTamano = this.onTamano;
    if (onTamano == null) return CustomPaint(size: Size.infinite, painter: painter);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth) {
          final tamano = painter.tamanoNecesario(constraints.maxWidth);
          WidgetsBinding.instance.addPostFrameCallback((_) => onTamano(tamano));
        }
        return CustomPaint(size: Size.infinite, painter: painter);
      },
    );
  }
}

class _EscalaPainter extends CustomPainter {
  _EscalaPainter({
    required this.metrosPorPx,
    required this.tipo,
    required this.color,
    required this.grosor,
    required this.ancho,
    required this.divisiones,
  });
  final double metrosPorPx;
  final TipoEscala tipo;
  final Color color;
  final double grosor;
  final double ancho;
  final int divisiones;

  /// Distancias "redondas" (1/2/5 × 10^n), de mayor a menor.
  static final List<double> _candidatos = [
    for (var exp = 7; exp >= -2; exp--)
      for (final p in const [5, 2, 1]) p * math.pow(10, exp).toDouble(),
  ];

  /// Una etiqueta por marca, desde 0 hasta [total]; la unidad (m o km, según
  /// el total) solo en la última para no saturar.
  static List<String> _etiquetas(double total, int divisiones) {
    final km = total >= 1000;
    final unidad = km ? 1000.0 : 1.0;
    return [
      for (var i = 0; i <= divisiones; i++)
        '${_numero(total * i / divisiones / unidad)}${i == divisiones ? (km ? ' km' : ' m') : ''}',
    ];
  }

  static String _numero(double v) {
    final texto = v.toStringAsFixed(v.abs() >= 100 ? 0 : 2);
    return texto.contains('.') ? texto.replaceFirst(RegExp(r'\.?0+$'), '') : texto;
  }

  TextPainter _texto(String s) => TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: 9, color: color)),
    textDirection: TextDirection.ltr,
  )..layout();

  /// La distancia más grande cuya barra, más media etiqueta a cada lado
  /// (centradas en la primera y última marca), cabe en [anchoDisponible].
  ({double barraPx, List<TextPainter> etiquetas}) _elegir(double anchoDisponible) {
    for (final candidato in _candidatos) {
      final px = candidato / metrosPorPx;
      final textos = [for (final s in _etiquetas(candidato, divisiones)) _texto(s)];
      final necesario = textos.first.width / 2 + px + textos.last.width / 2;
      if (necesario <= anchoDisponible || candidato == _candidatos.last) {
        return (barraPx: px, etiquetas: textos);
      }
      for (final t in textos) {
        t.dispose();
      }
    }
    throw StateError('sin candidatos');
  }

  /// Alto del trazo (marcas o barra) sobre las etiquetas.
  double get _altoTrazo => switch (tipo) {
    TipoEscala.linea => math.max(6, grosor * 3).toDouble(),
    TipoEscala.barra => ancho + 1,
  };

  /// Tamaño que ocupa la escala dibujada en [anchoDisponible]: el ancho de
  /// la barra con sus etiquetas de los extremos y el alto hasta el texto.
  Size tamanoNecesario(double anchoDisponible) {
    final (:barraPx, :etiquetas) = _elegir(anchoDisponible);
    final tamano = Size(
      // +1 px de holgura para que al ajustar el recuadro se siga eligiendo
      // la misma distancia pese al redondeo.
      etiquetas.first.width / 2 + barraPx + etiquetas.last.width / 2 + 1,
      _altoTrazo + 2 + etiquetas.map((t) => t.height).reduce(math.max) + 1,
    );
    for (final t in etiquetas) {
      t.dispose();
    }
    return tamano;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (:barraPx, :etiquetas) = _elegir(size.width);
    final x0 = etiquetas.first.width / 2;
    final marcasX = [for (var i = 0; i <= divisiones; i++) x0 + barraPx * i / divisiones];
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = tipo == TipoEscala.linea ? grosor : 1;

    final abajo = _altoTrazo;
    switch (tipo) {
      case TipoEscala.linea:
        final altoMarca = abajo;
        final y = altoMarca - grosor / 2;
        canvas.drawLine(Offset(marcasX.first, y), Offset(marcasX.last, y), trazo);
        for (final x in marcasX) {
          canvas.drawLine(Offset(x, 0), Offset(x, altoMarca), trazo);
        }
      case TipoEscala.barra:
        final relleno = Paint()..color = color;
        final blanco = Paint()..color = Colors.white.withValues(alpha: color.a);
        for (var i = 0; i < divisiones; i++) {
          final r = Rect.fromLTRB(marcasX[i], 0.5, marcasX[i + 1], 0.5 + ancho);
          canvas.drawRect(r, i.isEven ? relleno : blanco);
        }
        canvas.drawRect(Rect.fromLTRB(marcasX.first, 0.5, marcasX.last, 0.5 + ancho), trazo);
    }

    // El 0 y el total siempre se rotulan; una intermedia se omite si se
    // encimaría con la anterior rotulada o con la final.
    double finAnterior = double.negativeInfinity;
    final inicioUltima = marcasX.last - etiquetas.last.width / 2;
    for (var i = 0; i <= divisiones; i++) {
      final t = etiquetas[i];
      final izquierda = marcasX[i] - t.width / 2;
      final extremo = i == 0 || i == divisiones;
      if (extremo || (izquierda >= finAnterior + 3 && izquierda + t.width + 3 <= inicioUltima)) {
        t.paint(canvas, Offset(izquierda, abajo + 2));
        finAnterior = izquierda + t.width;
      }
      t.dispose();
    }
  }

  @override
  bool shouldRepaint(_EscalaPainter old) =>
      old.metrosPorPx != metrosPorPx ||
      old.tipo != tipo ||
      old.color != color ||
      old.grosor != grosor ||
      old.ancho != ancho ||
      old.divisiones != divisiones;
}
