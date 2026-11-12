import '../../../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import '../../utils/color_hex.dart';
import 'color_wheel_picker.dart';

/// Selector de color estándar para toda propiedad de color de un
/// elemento: una etiqueta ("Color de trazo", "Color de texto", etc.)
/// seguida de un recuadro con el color activo; tocar el recuadro abre la
/// rueda cromática dentro del panel para elegir el color deseado.
/// Siempre incluye un enlace "Sin color" junto al recuadro (que se muestra
/// con una línea diagonal en ese caso) y un control de opacidad debajo.
/// Si [permitirSinColor] es `true`, "Sin color" deja la propiedad en `null`;
/// si no, la deja en [hexSinColor] (transparente), porque en esas
/// propiedades `null` significa "color por defecto".
/// La opacidad se guarda en el canal alfa del hex (`#AARRGGBB`), salvo que
/// se pasen [opacidad] y [onOpacidadChanged] para propiedades que ya la
/// guardan en un campo propio.
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
    this.opacidad,
    this.onOpacidadChanged,
  });

  final String? colorHex;
  final ValueChanged<String?> onChanged;
  final bool permitirSinColor;
  final String? label;
  final TextStyle? textStyle;
  final Widget? trailing;
  final double? opacidad;
  final ValueChanged<double>? onOpacidadChanged;
  // Si es `true`, omite la etiqueta y solo dibuja el recuadro de color, el
  // enlace "Sin color" y la opacidad -pensado para compartir renglón con otro
  // control, p.ej. el switch de activación de un buffer.
  final bool compacto;

  @override
  State<ColorSwatchPicker> createState() => _ColorSwatchPickerState();
}

class _ColorSwatchPickerState extends State<ColorSwatchPicker> {
  bool abierto = false;

  bool get _opacidadExterna => widget.onOpacidadChanged != null;

  double get _opacidadActual => _opacidadExterna
      ? (widget.opacidad ?? 1).clamp(0, 1).toDouble()
      : colorFromHex(widget.colorHex)?.a ?? 1;

  void _quitarColor() =>
      widget.onChanged(widget.permitirSinColor ? null : hexSinColor);

  // La rueda entrega colores opacos (`#RRGGBB`); se les reaplica la
  // opacidad vigente. Al salir de "sin color" se vuelve a opaco.
  void _cambiarDesdeRueda(String hex) {
    if (_opacidadExterna) {
      widget.onChanged(hex);
      return;
    }
    final alfa = esSinColor(widget.colorHex) ? 1.0 : _opacidadActual;
    final color = colorFromHex(hex)!.withValues(alpha: alfa);
    widget.onChanged(alfa >= 1 ? hex : colorToHexConAlpha(color));
  }

  void _cambiarOpacidad(double v) {
    if (_opacidadExterna) {
      widget.onOpacidadChanged!(v);
      return;
    }
    final color = colorFromHex(widget.colorHex);
    if (color == null) return;
    widget.onChanged(colorToHexConAlpha(color.withValues(alpha: v)));
  }

  @override
  Widget build(BuildContext context) {
    final sinColor = esSinColor(widget.colorHex);
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
              border: Border.all(color: AppColors.border),
            ),
            child: sinColor
                ? CustomPaint(painter: _DiagonalLinePainter())
                : null,
          ),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 8),
          Expanded(child: widget.trailing!),
        ],
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _quitarColor,
          child: Text(
            'Sin color',
            style:
                (widget.textStyle ??
                        TextStyle(fontSize: 12, color: AppColors.textSecondary))
                    .copyWith(decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
    final controles = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        swatch,
        if (!sinColor)
          Row(
            children: [
              SizedBox(
                width: 92,
                child: Text(
                  'Opacidad: ${(_opacidadActual * 100).round()}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: Slider(
                  value: _opacidadActual,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  onChanged: _cambiarOpacidad,
                ),
              ),
            ],
          ),
        if (abierto)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ColorWheelPanel(
              initialHex: widget.colorHex,
              onChanged: _cambiarDesdeRueda,
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
