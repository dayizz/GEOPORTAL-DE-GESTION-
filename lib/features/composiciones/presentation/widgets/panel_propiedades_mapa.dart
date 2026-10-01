import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';
import 'color_swatch_picker.dart';
import 'panel_seccion_colapsable.dart';

const _opcionesBaseLayer = [
  ('estandar', 'Estándar'),
  ('satelital', 'Satelital'),
  ('satelitalSinEtiquetas', 'Satelital (sin etiquetas)'),
  ('sinMapa', 'Sin mapa base'),
];

const _opcionesFigura = [
  (FormaMarco.cuadrada, 'Cuadrada', Icons.crop_square),
  (FormaMarco.circular, 'Circular', Icons.circle_outlined),
  (FormaMarco.triangular, 'Triangular', Icons.change_history),
  (FormaMarco.hexagonal, 'Hexagonal', Icons.hexagon_outlined),
];

/// Tamaño de píxel estándar (OGC/WMTS, 0.28mm) usado para convertir entre
/// zoom de tiles y una escala cartográfica 1:N legible.
const _metrosPorPixelEstandar = 0.00028;

double _zoomAEscala(double zoom, double lat) {
  final metrosPorPixel = 156543.03392 * math.cos(lat * math.pi / 180) / math.pow(2, zoom);
  return metrosPorPixel / _metrosPorPixelEstandar;
}

double _escalaAZoom(double escala, double lat) {
  final metrosPorPixel = escala * _metrosPorPixelEstandar;
  final base = 156543.03392 * math.cos(lat * math.pi / 180) / metrosPorPixel;
  return math.log(base) / math.ln2;
}

/// Fila "etiqueta + caja de texto numérica" (con sufijo, p.ej. '°' o '%')
/// reusada por rotación y las opacidades. [valorTexto] ya viene formateado
/// por quien llama (redondeado/con decimales) para que lo que se ve en el
/// campo coincida con lo que muestra la etiqueta del slider debajo.
Widget _filaNumerica({
  required Key key,
  required String label,
  required String valorTexto,
  required String sufijo,
  required ValueChanged<double> onChanged,
}) {
  return Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 68,
        child: TextFormField(
          key: key,
          initialValue: valorTexto,
          textAlign: TextAlign.end,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            suffixText: sufijo,
          ),
          onChanged: (value) {
            final parsed = double.tryParse(value);
            if (parsed != null) onChanged(parsed);
          },
        ),
      ),
    ],
  );
}

/// Panel de propiedades para [TipoElemento.mapa]. El centro del mapa ya
/// no se edita aquí como texto: se ajusta arrastrando el mapa en modo
/// edición (doble click sobre la ventana), igual que el zoom con la
/// rueda del mouse. Este panel cubre lo que no se puede ajustar con
/// gestos: escala numérica, rotación del contenido (no de la ventana),
/// forma del marco y opacidades.
class PanelPropiedadesMapa extends StatelessWidget {
  const PanelPropiedadesMapa({
    super.key,
    required this.elemento,
    required this.onZoomChanged,
    required this.onBaseLayerChanged,
    required this.onMostrarClavesChanged,
    required this.onMostrarPksChanged,
    required this.onRotacionMapaChanged,
    required this.onFiguraChanged,
    required this.onOpacidadMapaChanged,
    required this.onOpacidadPrediosChanged,
    required this.onBordeActivoChanged,
    required this.onBordeGrosorChanged,
    required this.onBordeColorChanged,
    required this.onBordeOpacidadChanged,
  });

  final ElementoComposicion elemento;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<String> onBaseLayerChanged;
  final ValueChanged<bool> onMostrarClavesChanged;
  final ValueChanged<bool> onMostrarPksChanged;
  final ValueChanged<double> onRotacionMapaChanged;
  final ValueChanged<FormaMarco> onFiguraChanged;
  final ValueChanged<double> onOpacidadMapaChanged;
  final ValueChanged<double> onOpacidadPrediosChanged;
  final ValueChanged<bool> onBordeActivoChanged;
  final ValueChanged<double> onBordeGrosorChanged;
  final ValueChanged<String> onBordeColorChanged;
  final ValueChanged<double> onBordeOpacidadChanged;

  @override
  Widget build(BuildContext context) {
    final baseLayerActual = elemento.mapaBaseLayer ?? 'estandar';
    final latActual = elemento.mapaLat ?? 20.72;
    final zoomActual = (elemento.mapaZoom ?? 12.0).clamp(1, 18).toDouble();
    final escalaActual = _zoomAEscala(zoomActual, latActual);
    final rotacionMapaActual = elemento.mapaRotacion ?? 0;
    final figuraActual = elemento.mapaFigura ?? FormaMarco.cuadrada;
    final opacidadMapaActual = elemento.mapaOpacidad ?? 1.0;
    final opacidadPrediosActual = elemento.prediosOpacidad ?? 0.35;
    final bordeActivo = elemento.mapaBordeActivo ?? false;
    final bordeGrosorActual = elemento.mapaBordeGrosor ?? 2.0;
    final bordeColorActual = elemento.mapaBordeColorHex ?? '#000000';
    final bordeOpacidadActual = elemento.mapaBordeOpacidad ?? 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelSeccionColapsable(
          titulo: 'Geometría y escala',
          icono: Icons.straighten,
          children: [
            const Text(
              'Escala',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('1 :', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('escala_${elemento.id}'),
                    initialValue: escalaActual.round().toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        onZoomChanged(
                          _escalaAZoom(parsed, latActual).clamp(1, 18),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _filaNumerica(
              key: ValueKey('rotacion_${elemento.id}'),
              label: 'Rotación del mapa',
              valorTexto: rotacionMapaActual.round().toString(),
              sufijo: '°',
              onChanged: (v) => onRotacionMapaChanged(v.clamp(0, 360)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Forma del marco',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _opcionesFigura.map((o) {
                final seleccionada = o.$1 == figuraActual;
                return ChoiceChip(
                  label: Text(o.$2, style: const TextStyle(fontSize: 11)),
                  avatar: Icon(o.$3, size: 15),
                  selected: seleccionada,
                  onSelected: (_) => onFiguraChanged(o.$1),
                );
              }).toList(),
            ),
          ],
        ),
        PanelSeccionColapsable(
          titulo: 'Estilo del mapa',
          icono: Icons.map_outlined,
          children: [
            const Text(
              'Tipo de mapa',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: baseLayerActual,
              isDense: true,
              items: _opcionesBaseLayer
                  .map(
                    (o) => DropdownMenuItem(
                      value: o.$1,
                      child: Text(o.$2, style: const TextStyle(fontSize: 12)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onBaseLayerChanged(v);
              },
            ),
            const SizedBox(height: 12),
            _filaNumerica(
              key: ValueKey('opacidad_mapa_${elemento.id}'),
              label: 'Opacidad del mapa',
              valorTexto: (opacidadMapaActual * 100).round().toString(),
              sufijo: '%',
              onChanged: (v) => onOpacidadMapaChanged((v / 100).clamp(0, 1)),
            ),
            const SizedBox(height: 4),
            _filaNumerica(
              key: ValueKey('opacidad_predios_${elemento.id}'),
              label: 'Opacidad de predios',
              valorTexto: (opacidadPrediosActual * 100).round().toString(),
              sufijo: '%',
              onChanged: (v) =>
                  onOpacidadPrediosChanged((v / 100).clamp(0, 1)),
            ),
          ],
        ),
        PanelSeccionColapsable(
          titulo: 'Capas y etiquetas',
          icono: Icons.layers_outlined,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Etiquetas de clave catastral',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: elemento.mapaMostrarClaves ?? false,
                  onChanged: onMostrarClavesChanged,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Etiquetas de PKS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: elemento.mapaMostrarPks ?? false,
                  onChanged: onMostrarPksChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Borde',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: bordeActivo,
                  onChanged: onBordeActivoChanged,
                ),
              ],
            ),
            if (bordeActivo) ...[
              const SizedBox(height: 6),
              Text(
                'Grosor: ${bordeGrosorActual.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Slider(
                value: bordeGrosorActual.clamp(0.5, 12),
                min: 0.5,
                max: 12,
                onChanged: onBordeGrosorChanged,
              ),
              const SizedBox(height: 6),
              ColorSwatchPicker(
                label: 'Color',
                colorHex: bordeColorActual,
                onChanged: (v) {
                  if (v != null) onBordeColorChanged(v);
                },
              ),
              const SizedBox(height: 12),
              _filaNumerica(
                key: ValueKey('opacidad_borde_${elemento.id}'),
                label: 'Opacidad del borde',
                valorTexto: (bordeOpacidadActual * 100).round().toString(),
                sufijo: '%',
                onChanged: (v) =>
                    onBordeOpacidadChanged((v / 100).clamp(0, 1)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
