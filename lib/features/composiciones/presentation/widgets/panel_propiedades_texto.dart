import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';
import 'color_swatch_picker.dart';

const List<String> composicionesFuentes = [
  'Inter',
  'Roboto',
  'Montserrat',
  'Merriweather',
  'Oswald',
  'Courier Prime',
];

/// Panel de propiedades para un elemento de tipo [TipoElemento.texto]:
/// familia tipográfica, tamaño, negrita/cursiva, color de texto y color
/// de fondo del contenedor (o "sin fondo").
class PanelPropiedadesTexto extends StatelessWidget {
  const PanelPropiedadesTexto({
    super.key,
    required this.elemento,
    required this.onFontFamilyChanged,
    required this.onFontSizeChanged,
    required this.onBoldChanged,
    required this.onItalicChanged,
    required this.onColorTextoChanged,
    required this.onColorFondoChanged,
  });

  final ElementoComposicion elemento;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<bool> onBoldChanged;
  final ValueChanged<bool> onItalicChanged;
  final ValueChanged<String> onColorTextoChanged;
  final ValueChanged<String?> onColorFondoChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fuente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: elemento.textoFontFamily ?? 'Inter',
          isDense: true,
          items: composicionesFuentes.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
          onChanged: (v) {
            if (v != null) onFontFamilyChanged(v);
          },
        ),
        const SizedBox(height: 12),
        Text('Tamaño: ${(elemento.textoFontSize ?? 16).toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        Slider(
          value: (elemento.textoFontSize ?? 16).clamp(8, 96),
          min: 8,
          max: 96,
          onChanged: onFontSizeChanged,
        ),
        Row(
          children: [
            Expanded(
              child: FilterChip(
                label: const Text('Negrita', style: TextStyle(fontSize: 11)),
                selected: elemento.textoBold ?? false,
                onSelected: onBoldChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilterChip(
                label: const Text('Cursiva', style: TextStyle(fontSize: 11)),
                selected: elemento.textoItalic ?? false,
                onSelected: onItalicChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ColorSwatchPicker(
          label: 'Color de texto',
          colorHex: elemento.textoColorHex,
          onChanged: (v) {
            if (v != null) onColorTextoChanged(v);
          },
        ),
        const SizedBox(height: 14),
        ColorSwatchPicker(
          label: 'Color de fondo',
          colorHex: elemento.textoColorFondoHex,
          permitirSinColor: true,
          onChanged: onColorFondoChanged,
        ),
      ],
    );
  }
}
