import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Dibuja el velo oscuro + el recuadro de selección para "Guardar vista de
/// mapa" (arrastrar para marcar el área deseada), con el mismo lenguaje
/// visual que el recorte de "Captura de pantalla" pero sin rasterizar
/// nada -aquí solo importan las coordenadas del recuadro, ver
/// `_confirmarVistaSeleccionada` en `mapa_screen.dart`-.
class VistaMapaSelectionPainter extends CustomPainter {
  const VistaMapaSelectionPainter({this.start, this.current});

  final Offset? start;
  final Offset? current;

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final full = Offset.zero & size;

    if (start == null || current == null) {
      canvas.drawRect(full, scrimPaint);
      return;
    }

    final rect = Rect.fromPoints(start!, current!);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(full)
      ..addRect(rect);
    canvas.drawPath(path, scrimPaint);

    canvas.drawRect(
      rect,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    const tam = 10.0;
    final manijaPaint = Paint()..color = Colors.white;
    final manijaBorde = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final esquina in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
      canvas.drawCircle(esquina, tam / 2, manijaPaint);
      canvas.drawCircle(esquina, tam / 2, manijaBorde);
    }
  }

  @override
  bool shouldRepaint(covariant VistaMapaSelectionPainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.current != current;
}
