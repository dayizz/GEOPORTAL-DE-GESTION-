import 'package:flutter/material.dart';
import '../../models/hoja.dart';
import 'color_swatch_picker.dart';

class PanelPropiedadesHoja extends StatelessWidget {
  const PanelPropiedadesHoja({
    super.key,
    required this.hoja,
    required this.onChanged,
    required this.onNumeracionChanged,
  });
  final Hoja hoja;
  final ValueChanged<Hoja> onChanged;
  final ValueChanged<Hoja> onNumeracionChanged;

  bool _valida(Hoja h) {
    final (w, a) = h.dimensionesMm;
    return w.isFinite &&
        a.isFinite &&
        w > 0 &&
        a > 0 &&
        h.margenIzquierda + h.margenDerecha < w &&
        h.margenArriba + h.margenAbajo < a;
  }

  @override
  Widget build(BuildContext context) {
    final (ancho, alto) = hoja.dimensionesMm;
    Widget numero(
      String label,
      double valor,
      Hoja Function(double) cambiar, {
      Key? key,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: key,
        initialValue: valor.toStringAsFixed(2),
        decoration: InputDecoration(labelText: label, isDense: true),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (v) {
          final n = double.tryParse((v ?? '').replaceAll(',', '.'));
          return n == null || !n.isFinite || n < 0 || !_valida(cambiar(n))
              ? 'Revisa la medida y los márgenes.'
              : null;
        },
        onChanged: (v) {
          final n = double.tryParse(v.replaceAll(',', '.'));
          if (n != null && n.isFinite && n >= 0 && _valida(cambiar(n))) {
            onChanged(cambiar(n));
          }
        },
      ),
    );
    Widget fila(Widget izquierda, Widget derecha) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: izquierda),
        const SizedBox(width: 8),
        Expanded(child: derecha),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Hoja de trabajo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TamanoHoja>(
          initialValue: hoja.tamano,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tamaño'),
          items: TamanoHoja.values.map((t) {
            final (w, h) = t.dimensionesMm;
            return DropdownMenuItem(
              value: t,
              child: Text(
                t == TamanoHoja.personalizado
                    ? 'Personalizado'
                    : '${t.etiqueta} (${(w / 10).toStringAsFixed(2)} × ${(h / 10).toStringAsFixed(2)} cm)',
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v == null) return;
            final siguiente = hoja.copyWith(tamano: v);
            if (_valida(siguiente)) {
              onChanged(siguiente);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Reduce los márgenes antes de cambiar a este tamaño.',
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        if (hoja.tamano == TamanoHoja.personalizado) ...[
          fila(
            numero(
              'Ancho (cm)',
              ancho / 10,
              (v) => hoja.copyWith(
                anchoPersonalizadoMm: v * 10,
                altoPersonalizadoMm: alto,
                horizontal: v * 10 > alto,
              ),
              key: ValueKey('ancho-${hoja.horizontal}'),
            ),
            numero(
              'Alto (cm)',
              alto / 10,
              (v) => hoja.copyWith(
                anchoPersonalizadoMm: ancho,
                altoPersonalizadoMm: v * 10,
                horizontal: ancho > v * 10,
              ),
              key: ValueKey('alto-${hoja.horizontal}'),
            ),
          ),
        ],
        DropdownButtonFormField<bool>(
          key: ValueKey('orientacion-${hoja.horizontal}'),
          initialValue: hoja.horizontal,
          decoration: const InputDecoration(labelText: 'Orientación'),
          items: const [
            DropdownMenuItem(value: false, child: Text('Vertical')),
            DropdownMenuItem(value: true, child: Text('Horizontal')),
          ],
          onChanged: (v) {
            if (v != null && _valida(hoja.copyWith(horizontal: v))) {
              onChanged(hoja.copyWith(horizontal: v));
            }
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Márgenes (mm)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        fila(
          numero(
            'Arriba',
            hoja.margenArriba,
            (v) => hoja.copyWith(margenSuperiorMm: v),
          ),
          numero(
            'Abajo',
            hoja.margenAbajo,
            (v) => hoja.copyWith(margenInferiorMm: v),
          ),
        ),
        fila(
          numero(
            'Izquierda',
            hoja.margenIzquierda,
            (v) => hoja.copyWith(margenIzquierdoMm: v),
          ),
          numero(
            'Derecha',
            hoja.margenDerecha,
            (v) => hoja.copyWith(margenDerechoMm: v),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Numerar página'),
          value: hoja.numerarPagina,
          onChanged: (v) =>
              onNumeracionChanged(hoja.copyWith(numerarPagina: v)),
        ),
        if (hoja.numerarPagina) ...[
          DropdownButtonFormField<int>(
            initialValue: hoja.inicioPagina,
            decoration: const InputDecoration(labelText: 'Inicio de página'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Primera hoja')),
              DropdownMenuItem(value: 2, child: Text('Segunda hoja')),
              DropdownMenuItem(value: 3, child: Text('Tercera hoja')),
            ],
            onChanged: (v) {
              if (v != null) {
                onNumeracionChanged(hoja.copyWith(inicioPagina: v));
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PosicionPagina>(
            initialValue: hoja.posicionPagina,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Posición'),
            items: PosicionPagina.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.etiqueta)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                onNumeracionChanged(hoja.copyWith(posicionPagina: v));
              }
            },
          ),
        ],
        const SizedBox(height: 12),
        ColorSwatchPicker(
          label: 'Color de hoja',
          colorHex: hoja.colorFondoHex ?? '#FFFFFF',
          onChanged: (v) => onChanged(hoja.copyWith(colorFondoHex: v)),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Opacidad: ${(hoja.opacidadFondo * 100).round()}%',
                style: const TextStyle(fontSize: 12),
              ),
              Slider(
                value: hoja.opacidadFondo.clamp(0, 1),
                min: 0,
                max: 1,
                divisions: 100,
                onChanged: (v) => onChanged(hoja.copyWith(opacidadFondo: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
