import 'panel_seccion_colapsable.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/elemento_composicion.dart';
import 'color_swatch_picker.dart';
import 'norte_widget.dart';

const _opcionesNorte = [
  (TipoNorte.flecha, 'Flecha'),
  (TipoNorte.mediaFlecha, 'Media flecha'),
  (TipoNorte.rosa, 'Rosa de los vientos'),
  (TipoNorte.circulo, 'Flecha en círculo'),
];

/// Panel de propiedades para [TipoElemento.norte]: diseño, color/opacidad
/// y orientación (manual, o siguiendo la rotación de un mapa de la hoja).
class PanelPropiedadesNorte extends StatelessWidget {
  const PanelPropiedadesNorte({
    super.key,
    required this.elemento,
    required this.mapasDisponibles,
    required this.onChanged,
  });

  final ElementoComposicion elemento;
  final List<ElementoComposicion> mapasDisponibles;
  final ValueChanged<ElementoComposicion Function(ElementoComposicion)> onChanged;

  @override
  Widget build(BuildContext context) {
    final tipoActual = elemento.norteTipo ?? TipoNorte.flecha;
    // Si el mapa vinculado se borró, el norte vuelve a orientación manual.
    final mapaActual = mapasDisponibles.any((m) => m.id == elemento.norteMapaId)
        ? elemento.norteMapaId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelSeccionColapsable(
          titulo: 'Estilo',
          icono: Icons.palette_outlined,
          children: [
            const Text('Diseño', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (tipo, nombre) in _opcionesNorte)
                  Tooltip(
                    message: nombre,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => onChanged((e) => e.copyWith(norteTipo: tipo)),
                      child: Container(
                        width: 46,
                        height: 54,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: tipo == tipoActual ? AppColors.primary : AppColors.border,
                            width: tipo == tipoActual ? 1.6 : 1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          color: tipo == tipoActual ? AppColors.primary.withValues(alpha: 0.08) : null,
                        ),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: NortePainter(tipo: tipo, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ColorSwatchPicker(
              label: 'Color',
              colorHex: elemento.norteColorHex ?? '#DE000000',
              onChanged: (v) {
                if (v != null) onChanged((e) => e.copyWith(norteColorHex: v));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
        PanelSeccionColapsable(
          titulo: 'Orientación',
          icono: Icons.explore_outlined,
          children: [
            DropdownButtonFormField<String?>(
              key: ValueKey('norte_mapa_${elemento.id}_$mapaActual'),
              initialValue: mapaActual,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Seguir orientación de', isDense: true),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Manual', style: TextStyle(fontSize: 12)),
                ),
                for (final m in mapasDisponibles)
                  DropdownMenuItem<String?>(
                    value: m.id,
                    child: Text(m.nombreCapa, style: const TextStyle(fontSize: 12)),
                  ),
              ],
              // Al vincular, el giro sale del mapa: se anula el manual para
              // que no se sume.
              onChanged: (v) => onChanged((e) => v == null
                  ? e.copyWith(clearNorteMapaId: true)
                  : e.copyWith(norteMapaId: v, rotacion: 0)),
            ),
            const SizedBox(height: 8),
            if (mapaActual != null)
              Text(
                'El norte gira automáticamente con la rotación del mapa.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            else ...[
              if (mapasDisponibles.isEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Agrega un mapa a esta hoja para que el norte siga su orientación.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              Text(
                'Orientación: ${elemento.rotacion.round()}°',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Slider(
                value: elemento.rotacion.clamp(0, 360),
                min: 0,
                max: 360,
                onChanged: (v) => onChanged((e) => e.copyWith(rotacion: v)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
