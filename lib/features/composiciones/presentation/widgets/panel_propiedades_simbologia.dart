import 'panel_seccion_colapsable.dart';
import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';
import 'color_swatch_picker.dart';
import 'panel_propiedades_texto.dart' show composicionesFuentes;
import 'simbologia_widget.dart' show tituloSimbologia;

const _etiqueta = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

const List<(int, String)> _grosores = [
  (300, 'Delgada'),
  (400, 'Normal'),
  (500, 'Media'),
  (600, 'Seminegrita'),
  (700, 'Negrita'),
  (800, 'Extra negrita'),
  (900, 'Black'),
];

/// Panel de propiedades para [TipoElemento.simbologia]: clasificación,
/// título (actual o personalizado), tipografía de título y etiquetas,
/// símbolos (tamaño, separación y columnas) y fondo.
class PanelPropiedadesSimbologia extends StatelessWidget {
  const PanelPropiedadesSimbologia({
    super.key,
    required this.elemento,
    required this.onChanged,
  });

  final ElementoComposicion elemento;
  final ValueChanged<ElementoComposicion Function(ElementoComposicion)> onChanged;

  EstiloSimbologia get _estilo => elemento.simbologiaEstilo;
  TipoSimbologia get _tipo => elemento.simbologiaTipo ?? TipoSimbologia.estatus;

  void _cambiarEstilo(EstiloSimbologia Function(EstiloSimbologia) f) =>
      onChanged((e) => e.copyWith(simbologiaEstilo: f(e.simbologiaEstilo)));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seccionClasificacion(),
        _seccionTitulo(),
        _seccionTexto(),
        _seccionSimbolos(),
        _seccionFondo(),
      ],
    );
  }

  Widget _seccionClasificacion() => PanelSeccionColapsable(
    titulo: 'Clasificación',
    icono: Icons.legend_toggle,
    children: [
      const Text('Simbología por', style: _etiqueta),
      const SizedBox(height: 8),
      DropdownButton<TipoSimbologia>(
        value: _tipo,
        isDense: true,
        isExpanded: true,
        items: TipoSimbologia.values
            .map((t) => DropdownMenuItem(value: t, child: Text(tituloSimbologia(t))))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged((e) => e.copyWith(simbologiaTipo: v));
        },
      ),
      const SizedBox(height: 8),
    ],
  );

  Widget _seccionTitulo() => PanelSeccionColapsable(
    titulo: 'Título',
    icono: Icons.title,
    children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Actual')),
          ButtonSegment(value: true, label: Text('Personalizado')),
        ],
        selected: {_estilo.tituloPersonalizado},
        showSelectedIcon: false,
        onSelectionChanged: (s) => _cambiarEstilo((st) => st.copyWith(
          tituloPersonalizado: s.first,
          // Al personalizar por primera vez se parte del título actual.
          tituloTexto: s.first && st.tituloTexto.isEmpty ? tituloSimbologia(_tipo) : null,
        )),
      ),
      const SizedBox(height: 8),
      if (_estilo.tituloPersonalizado)
        TextFormField(
          key: ValueKey('simb-titulo-${elemento.id}'),
          initialValue: _estilo.tituloTexto,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Título',
            helperText: 'Déjalo vacío para ocultar el título',
          ),
          onChanged: (v) => _cambiarEstilo((st) => st.copyWith(tituloTexto: v)),
        )
      else
        Text('Título: ${tituloSimbologia(_tipo)}', style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 8),
    ],
  );

  Widget _seccionTexto() => PanelSeccionColapsable(
    titulo: 'Texto',
    icono: Icons.text_fields,
    children: [
      const Text('Título', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      _EditorEstiloTexto(
        estilo: _estilo.estiloTitulo,
        onChanged: (v) => _cambiarEstilo((st) => st.copyWith(estiloTitulo: v)),
      ),
      const Divider(height: 24),
      const Text('Subtítulos (etiquetas)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      _EditorEstiloTexto(
        estilo: _estilo.estiloEtiquetas,
        onChanged: (v) => _cambiarEstilo((st) => st.copyWith(estiloEtiquetas: v)),
      ),
      const SizedBox(height: 8),
    ],
  );

  Widget _seccionSimbolos() => PanelSeccionColapsable(
    titulo: 'Símbolos',
    icono: Icons.crop_square,
    children: [
      Text('Tamaño de símbolo: ${_estilo.tamanoSimbolo.toStringAsFixed(0)} px', style: _etiqueta),
      Slider(
        value: _estilo.tamanoSimbolo.clamp(4, 40),
        min: 4,
        max: 40,
        divisions: 36,
        onChanged: (v) => _cambiarEstilo((st) => st.copyWith(tamanoSimbolo: v)),
      ),
      Text('Separación símbolo-texto: ${_estilo.separacion.toStringAsFixed(0)} px', style: _etiqueta),
      Slider(
        value: _estilo.separacion.clamp(0, 40),
        min: 0,
        max: 40,
        divisions: 40,
        onChanged: (v) => _cambiarEstilo((st) => st.copyWith(separacion: v)),
      ),
      const Text('Columnas', style: _etiqueta),
      const SizedBox(height: 6),
      SegmentedButton<int>(
        segments: [
          for (var c = 1; c <= 4; c++) ButtonSegment(value: c, label: Text('$c')),
        ],
        selected: {_estilo.columnas.clamp(1, 4)},
        showSelectedIcon: false,
        onSelectionChanged: (s) => _cambiarEstilo((st) => st.copyWith(columnas: s.first)),
      ),
      const SizedBox(height: 8),
    ],
  );

  Widget _seccionFondo() => PanelSeccionColapsable(
    titulo: 'Fondo',
    icono: Icons.format_color_fill,
    children: [
      Row(
        children: [
          const Expanded(child: Text('Mostrar fondo', style: _etiqueta)),
          Switch(
            value: _estilo.fondoActivo,
            onChanged: (v) => _cambiarEstilo((st) => st.copyWith(fondoActivo: v)),
          ),
        ],
      ),
      if (_estilo.fondoActivo)
        ColorSwatchPicker(
          label: 'Color',
          colorHex: _estilo.fondoColorHex,
          opacidad: _estilo.fondoOpacidad,
          onOpacidadChanged: (v) => _cambiarEstilo((st) => st.copyWith(fondoOpacidad: v)),
          onChanged: (v) {
            if (v != null) _cambiarEstilo((st) => st.copyWith(fondoColorHex: v));
          },
        ),
      const SizedBox(height: 8),
    ],
  );
}

/// Controles de fuente, tamaño, grosor, estilo y color de un texto de la
/// simbología.
class _EditorEstiloTexto extends StatelessWidget {
  const _EditorEstiloTexto({required this.estilo, required this.onChanged});

  final EstiloTextoSimbologia estilo;
  final ValueChanged<EstiloTextoSimbologia> onChanged;

  @override
  Widget build(BuildContext context) {
    final grosor = _grosores.any((g) => g.$1 == estilo.grosor) ? estilo.grosor : 400;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo de letra', style: _etiqueta),
        DropdownButton<String>(
          value: composicionesFuentes.contains(estilo.fuente) ? estilo.fuente : 'Inter',
          isDense: true,
          isExpanded: true,
          items: composicionesFuentes
              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(estilo.copyWith(fuente: v));
          },
        ),
        const SizedBox(height: 10),
        Text('Tamaño: ${estilo.tamano.toStringAsFixed(1)} pt', style: _etiqueta),
        Slider(
          value: estilo.tamano.clamp(5, 36),
          min: 5,
          max: 36,
          divisions: 62,
          onChanged: (v) => onChanged(estilo.copyWith(tamano: v)),
        ),
        const Text('Grosor', style: _etiqueta),
        DropdownButton<int>(
          value: grosor,
          isDense: true,
          isExpanded: true,
          items: _grosores
              .map((g) => DropdownMenuItem(
                    value: g.$1,
                    child: Text(g.$2, style: TextStyle(fontWeight: FontWeight.values[g.$1 ~/ 100 - 1])),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(estilo.copyWith(grosor: v));
          },
        ),
        const SizedBox(height: 10),
        const Text('Estilo', style: _etiqueta),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Normal')),
            ButtonSegment(
              value: true,
              label: Text('Cursiva', style: TextStyle(fontStyle: FontStyle.italic)),
            ),
          ],
          selected: {estilo.cursiva},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(estilo.copyWith(cursiva: s.first)),
        ),
        const SizedBox(height: 10),
        ColorSwatchPicker(
          label: 'Color',
          colorHex: estilo.colorHex,
          onChanged: (v) {
            if (v != null) onChanged(estilo.copyWith(colorHex: v));
          },
        ),
      ],
    );
  }
}
