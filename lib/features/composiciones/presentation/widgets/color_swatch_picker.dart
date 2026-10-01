import 'package:flutter/material.dart';
import '../../utils/color_hex.dart';
import 'color_wheel_picker.dart';

/// Selector de color estándar para toda propiedad de color de un
/// elemento: una etiqueta ("Color de trazo", "Color de texto", etc.)
/// seguida de un recuadro con el color activo; tocar el recuadro abre la
/// rueda cromática ([showColorWheelDialog]) para elegir el color deseado.
/// Si [permitirSinColor] es `true`, se agrega un enlace "Sin color" junto
/// al recuadro para poder dejar la propiedad sin valor (el recuadro se
/// muestra con un patrón de línea diagonal en ese caso).
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.colorHex,
    required this.onChanged,
    this.permitirSinColor = false,
    this.label,
    this.compacto = false,
  });

  final String? colorHex;
  final ValueChanged<String?> onChanged;
  final bool permitirSinColor;
  final String? label;
  // Si es `true`, omite la etiqueta y solo dibuja el recuadro de color (y el
  // enlace "Sin color", si aplica) -pensado para compartir renglón con otro
  // control, p.ej. el switch de activación de un buffer.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final swatch = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () async {
            final resultado = await showColorWheelDialog(context, initialHex: colorHex);
            if (resultado != null) onChanged(resultado);
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorFromHex(colorHex),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black26),
            ),
            child: colorHex == null ? CustomPaint(painter: _DiagonalLinePainter()) : null,
          ),
        ),
        if (permitirSinColor) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => onChanged(null),
            child: const Text(
              'Sin color',
              style: TextStyle(fontSize: 11, color: Colors.black54, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ],
    );
    if (compacto) return swatch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label ?? 'Color', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        swatch,
      ],
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(2, size.height - 2), Offset(size.width - 2, 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
