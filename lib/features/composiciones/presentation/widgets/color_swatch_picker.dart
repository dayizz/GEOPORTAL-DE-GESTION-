import 'package:flutter/material.dart';
import '../../utils/color_hex.dart';
import 'color_wheel_picker.dart';

/// Selector de color simple: una grilla de colores preestablecidos + un
/// botón que abre una rueda de matiz/saturación (más brillo aparte) para
/// cualquier tono fuera de la paleta + opcionalmente un botón "Sin
/// color". No depende de ningún paquete de selector de color (no hay
/// ninguno instalado en el proyecto).
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.colorHex,
    required this.onChanged,
    this.permitirSinColor = false,
    this.label,
  });

  final String? colorHex;
  final ValueChanged<String?> onChanged;
  final bool permitirSinColor;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (permitirSinColor) _buildSinColor(),
            ...composicionesPaletaColores.map(_buildSwatch),
            BotonRuedaColor(colorHex: colorHex, onChanged: onChanged),
          ],
        ),
      ],
    );
  }

  Widget _buildSwatch(String hex) {
    final seleccionado = colorHex?.toUpperCase() == hex.toUpperCase();
    return GestureDetector(
      onTap: () => onChanged(hex),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: colorFromHex(hex),
          shape: BoxShape.circle,
          border: Border.all(
            color: seleccionado ? Colors.black : Colors.black26,
            width: seleccionado ? 2 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildSinColor() {
    final seleccionado = colorHex == null;
    return GestureDetector(
      onTap: () => onChanged(null),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: seleccionado ? Colors.black : Colors.black26, width: seleccionado ? 2 : 1),
        ),
        child: CustomPaint(painter: _DiagonalLinePainter()),
      ),
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
