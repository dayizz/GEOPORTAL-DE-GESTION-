import '../../../../core/constants/app_colors.dart';
import 'panel_seccion_colapsable.dart';
import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';
import 'color_swatch_picker.dart';

const _titulo = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

/// Panel de propiedades para [TipoElemento.escala]: elegir a qué mapa de
/// la misma hoja se asocia (de ahí se deriva la relación metros/px) y el
/// estilo de la escala (línea o barra, color, grosor/ancho y divisiones).
class PanelPropiedadesEscala extends StatelessWidget {
  const PanelPropiedadesEscala({
    super.key,
    required this.elemento,
    required this.mapasDisponibles,
    required this.onMapaIdChanged,
    required this.onChanged,
  });

  final ElementoComposicion elemento;
  final List<ElementoComposicion> mapasDisponibles;
  final ValueChanged<String?> onMapaIdChanged;
  final ValueChanged<ElementoComposicion Function(ElementoComposicion)> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seccionMapa(),
        _seccionEstilo(),
      ],
    );
  }

  Widget _seccionMapa() {
    if (mapasDisponibles.isEmpty) {
      return PanelSeccionColapsable(titulo: 'Mapa asociado', icono: Icons.straighten, children: [Text(
        'Agrega un elemento de mapa a esta hoja para poder asociarle una escala.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      )]);
    }
    final valorValido =
        mapasDisponibles.any((m) => m.id == elemento.escalaMapaId)
        ? elemento.escalaMapaId
        : null;
    return PanelSeccionColapsable(
      titulo: 'Mapa asociado',
      icono: Icons.straighten,
      children: [
        DropdownButtonFormField<String>(
          initialValue: valorValido,
          isDense: true,
          hint: const Text(
            'Selecciona un mapa',
            style: TextStyle(fontSize: 12),
          ),
          items: mapasDisponibles
              .map(
                (m) => DropdownMenuItem(value: m.id, child: Text(m.nombreCapa)),
              )
              .toList(),
          onChanged: onMapaIdChanged,
        ),
      ],
    );
  }

  Widget _seccionEstilo() {
    final tipo = elemento.escalaTipo ?? TipoEscala.linea;
    final grosor = elemento.escalaGrosor ?? 1.4;
    final ancho = elemento.escalaAncho ?? 6;
    final divisiones = elemento.escalaDivisiones ?? 2;
    return PanelSeccionColapsable(
      titulo: 'Estilo',
      icono: Icons.palette_outlined,
      children: [
        SegmentedButton<TipoEscala>(
          segments: const [
            ButtonSegment(value: TipoEscala.linea, label: Text('Línea'), icon: Icon(Icons.horizontal_rule)),
            ButtonSegment(value: TipoEscala.barra, label: Text('Barra'), icon: Icon(Icons.view_week_outlined)),
          ],
          selected: {tipo},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged((e) => e.copyWith(escalaTipo: s.first)),
        ),
        const SizedBox(height: 12),
        if (tipo == TipoEscala.linea) ...[
          Text('Grosor de línea: ${grosor.toStringAsFixed(1)} px', style: _titulo),
          Slider(
            value: grosor.clamp(0.5, 6),
            min: 0.5,
            max: 6,
            divisions: 11,
            onChanged: (v) => onChanged((e) => e.copyWith(escalaGrosor: v)),
          ),
        ] else ...[
          Text('Ancho de barra: ${ancho.toStringAsFixed(0)} px', style: _titulo),
          Slider(
            value: ancho.clamp(2, 20),
            min: 2,
            max: 20,
            divisions: 18,
            onChanged: (v) => onChanged((e) => e.copyWith(escalaAncho: v)),
          ),
        ],
        Text('Divisiones: $divisiones', style: _titulo),
        Slider(
          value: divisiones.clamp(1, 5).toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          onChanged: (v) => onChanged((e) => e.copyWith(escalaDivisiones: v.round())),
        ),
        const SizedBox(height: 4),
        ColorSwatchPicker(
          label: 'Color',
          colorHex: elemento.escalaColorHex ?? '#DE000000',
          onChanged: (v) {
            if (v != null) onChanged((e) => e.copyWith(escalaColorHex: v));
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
