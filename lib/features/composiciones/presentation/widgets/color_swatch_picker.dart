import 'package:flutter/material.dart';
import '../../utils/color_hex.dart';
import 'color_wheel_picker.dart';

/// Selector de color estándar para toda propiedad de color de un
/// elemento: una etiqueta ("Color de trazo", "Color de texto", etc.)
/// seguida de un recuadro con el color activo; tocar el recuadro abre la
/// rueda cromática dentro del panel para elegir el color deseado.
/// Si [permitirSinColor] es `true`, se agrega un enlace "Sin color" junto
/// al recuadro para poder dejar la propiedad sin valor (el recuadro se
/// muestra con un patrón de línea diagonal en ese caso).
class ColorSwatchPicker extends StatefulWidget {
  const ColorSwatchPicker({
    super.key,
    required this.colorHex,
    required this.onChanged,
    this.permitirSinColor = false,
    this.label,
    this.compacto = false,
    this.textStyle,
    this.trailing,
  });

  final String? colorHex;
  final ValueChanged<String?> onChanged;
  final bool permitirSinColor;
  final String? label;
  final TextStyle? textStyle;
  final Widget? trailing;
  // Si es `true`, omite la etiqueta y solo dibuja el recuadro de color (y el
  // enlace "Sin color", si aplica) -pensado para compartir renglón con otro
  // control, p.ej. el switch de activación de un buffer.
  final bool compacto;

  @override
  State<ColorSwatchPicker> createState() => _ColorSwatchPickerState();
}

class _ColorSwatchPickerState extends State<ColorSwatchPicker> {
  bool abierto = false;
  @override
  Widget build(BuildContext context) {
    final swatch = Row(
      mainAxisSize: widget.trailing == null
          ? MainAxisSize.min
          : MainAxisSize.max,
      children: [
        GestureDetector(
          onTap: () => setState(() => abierto = !abierto),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorFromHex(widget.colorHex),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black26),
            ),
            child: widget.colorHex == null
                ? CustomPaint(painter: _DiagonalLinePainter())
                : null,
          ),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 8),
          Expanded(child: widget.trailing!),
        ],
        if (widget.permitirSinColor) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => widget.onChanged(null),
            child: Text(
              'Sin color',
              style:
                  (widget.textStyle ??
                          const TextStyle(fontSize: 12, color: Colors.black54))
                      .copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ],
      ],
    );
    final controles = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        swatch,
        if (abierto)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ColorWheelPanel(
              initialHex: widget.colorHex,
              onChanged: widget.onChanged,
            ),
          ),
      ],
    );
    if (widget.compacto) return controles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label ?? 'Color',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        controles,
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
    canvas.drawLine(
      Offset(2, size.height - 2),
      Offset(size.width - 2, 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
