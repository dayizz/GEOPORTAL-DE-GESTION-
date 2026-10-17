import 'package:flutter/material.dart';
import '../../models/hoja.dart';
import 'color_swatch_picker.dart';

class HerramientaHojaResultado {
  const HerramientaHojaResultado({
    required this.tamano,
    required this.horizontal,
    required this.margenMm,
    required this.colorFondoHex,
  });

  final TamanoHoja tamano;
  final bool horizontal;
  final double margenMm;
  final String? colorFondoHex;
}

/// Diálogo de propiedades de la hoja activa: tamaño, orientación, margen
/// y color de fondo.
Future<HerramientaHojaResultado?> mostrarHerramientaHojaDialog(
  BuildContext context, {
  required Hoja hoja,
}) async {
  var tamano = hoja.tamano;
  var horizontal = hoja.horizontal;
  final margenCtrl = TextEditingController(text: hoja.margenMm.toString());
  final formKey = GlobalKey<FormState>();
  String? colorFondoHex = hoja.colorFondoHex;
  const labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  const valueStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.normal);
  const decoration = InputDecoration(
    isDense: true,
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: labelStyle),
  );
  String mm(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  final route = DialogRoute<HerramientaHojaResultado>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: const Text(
            'Propiedades de la hoja',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    label('Tamaño'),
                    DropdownButtonFormField<TamanoHoja>(
                      initialValue: tamano,
                      isExpanded: true,
                      style: valueStyle.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurface,
                      ),
                      decoration: decoration,
                      items: TamanoHoja.values.map((t) {
                        final (w, h) = t.dimensionesMm;
                        return DropdownMenuItem(
                          value: t,
                          child: Text(
                            '${t.etiqueta} (${mm(horizontal ? h : w)} × ${mm(horizontal ? w : h)} mm)',
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => tamano = v ?? tamano),
                    ),
                    const SizedBox(height: 16),
                    label('Orientación'),
                    DropdownButtonFormField<bool>(
                      initialValue: horizontal,
                      isExpanded: true,
                      style: valueStyle.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurface,
                      ),
                      decoration: decoration,
                      items: const [
                        DropdownMenuItem(value: false, child: Text('Vertical')),
                        DropdownMenuItem(
                          value: true,
                          child: Text('Horizontal'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => horizontal = v ?? horizontal),
                    ),
                    const SizedBox(height: 16),
                    label('Margen (mm)'),
                    TextFormField(
                      controller: margenCtrl,
                      style: valueStyle,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: decoration.copyWith(
                        helperText: '0 = sin límite de margen.',
                        helperStyle: valueStyle,
                      ),
                      validator: (text) {
                        final m = double.tryParse(
                          (text ?? '').trim().replaceAll(',', '.'),
                        );
                        if (m == null || !m.isFinite || m < 0) {
                          return 'Introduce un margen válido mayor o igual a 0.';
                        }
                        final (w, h) = tamano.dimensionesMm;
                        if (2 * m >= w || 2 * m >= h) {
                          return 'El margen debe dejar espacio útil en la hoja.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    label('Color de fondo'),
                    ColorSwatchPicker(
                      compacto: true,
                      textStyle: valueStyle,
                      colorHex: colorFondoHex,
                      permitirSinColor: true,
                      onChanged: (v) => setState(() => colorFondoHex = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: valueStyle),
            ),
            TextButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  ctx,
                  HerramientaHojaResultado(
                    tamano: tamano,
                    horizontal: horizontal,
                    margenMm: double.parse(
                      margenCtrl.text.trim().replaceAll(',', '.'),
                    ),
                    colorFondoHex: colorFondoHex,
                  ),
                );
              },
              child: const Text('Aplicar', style: valueStyle),
            ),
          ],
        );
      },
    ),
  );
  try {
    return await Navigator.of(context, rootNavigator: true).push(route);
  } finally {
    await route.completed;
    margenCtrl.dispose();
  }
}
