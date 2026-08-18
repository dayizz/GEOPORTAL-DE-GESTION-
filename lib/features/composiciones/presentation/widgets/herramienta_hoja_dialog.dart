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
}) {
  var tamano = hoja.tamano;
  var horizontal = hoja.horizontal;
  var margenCtrl = TextEditingController(text: hoja.margenMm.toStringAsFixed(0));
  String? colorFondoHex = hoja.colorFondoHex;

  return showDialog<HerramientaHojaResultado>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Propiedades de la hoja'),
            content: SizedBox(
              width: 340,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Tamaño', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<TamanoHoja>(
                      initialValue: tamano,
                      isDense: true,
                      items: TamanoHoja.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.etiqueta)))
                          .toList(),
                      onChanged: (v) => setState(() => tamano = v ?? tamano),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Horizontal', style: TextStyle(fontSize: 12)),
                        Switch(
                          value: horizontal,
                          onChanged: (v) => setState(() => horizontal = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: margenCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Margen (mm)', isDense: true),
                    ),
                    const SizedBox(height: 16),
                    ColorSwatchPicker(
                      label: 'Color de fondo',
                      colorHex: colorFondoHex,
                      permitirSinColor: true,
                      onChanged: (v) => setState(() => colorFondoHex = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () {
                  final margen = double.tryParse(margenCtrl.text.trim()) ?? hoja.margenMm;
                  Navigator.pop(
                    ctx,
                    HerramientaHojaResultado(
                      tamano: tamano,
                      horizontal: horizontal,
                      margenMm: margen,
                      colorFondoHex: colorFondoHex,
                    ),
                  );
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      );
    },
  );
}
