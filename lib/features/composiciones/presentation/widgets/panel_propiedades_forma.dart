import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';
import 'color_swatch_picker.dart';

/// Panel de propiedades para un elemento de tipo [TipoElemento.forma]:
/// color de trazo, grosor y color de relleno (o "sin relleno").
class PanelPropiedadesForma extends StatelessWidget {
  const PanelPropiedadesForma({
    super.key,
    required this.elemento,
    required this.onColorTrazoChanged,
    required this.onGrosorChanged,
    required this.onColorRellenoChanged,
  });

  final ElementoComposicion elemento;
  final ValueChanged<String> onColorTrazoChanged;
  final ValueChanged<double> onGrosorChanged;
  final ValueChanged<String?> onColorRellenoChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ColorSwatchPicker(
          label: 'Color de trazo',
          colorHex: elemento.colorTrazoHex,
          onChanged: (v) {
            if (v != null) onColorTrazoChanged(v);
          },
        ),
        const SizedBox(height: 14),
        Text('Grosor de trazo: ${(elemento.grosorTrazo ?? 2).toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        Slider(
          value: (elemento.grosorTrazo ?? 2).clamp(0.5, 12),
          min: 0.5,
          max: 12,
          onChanged: onGrosorChanged,
        ),
        const SizedBox(height: 8),
        ColorSwatchPicker(
          label: 'Color de relleno',
          colorHex: elemento.colorRellenoHex,
          permitirSinColor: true,
          onChanged: onColorRellenoChanged,
        ),
      ],
    );
  }
}
