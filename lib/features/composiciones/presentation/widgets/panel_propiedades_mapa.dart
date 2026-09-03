import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';

const _opcionesBaseLayer = [
  ('estandar', 'Estándar'),
  ('satelital', 'Satelital'),
  ('satelitalSinEtiquetas', 'Satelital (sin etiquetas)'),
  ('sinMapa', 'Sin mapa base'),
];

/// Panel de propiedades para [TipoElemento.mapa]: tipo de mapa base y si
/// se muestran las etiquetas de clave catastral, igual que en la
/// pantalla Mapa (ver `mapaBaseLayer`/`mapaMostrarClaves` en
/// `ElementoComposicion`).
class PanelPropiedadesMapa extends StatelessWidget {
  const PanelPropiedadesMapa({
    super.key,
    required this.elemento,
    required this.onLatChanged,
    required this.onLngChanged,
    required this.onZoomChanged,
    required this.onBaseLayerChanged,
    required this.onMostrarClavesChanged,
  });

  final ElementoComposicion elemento;
  final ValueChanged<double> onLatChanged;
  final ValueChanged<double> onLngChanged;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<String> onBaseLayerChanged;
  final ValueChanged<bool> onMostrarClavesChanged;

  @override
  Widget build(BuildContext context) {
    final baseLayerActual = elemento.mapaBaseLayer ?? 'estandar';
    final latActual = elemento.mapaLat ?? 20.72;
    final lngActual = elemento.mapaLng ?? -100.35;
    final zoomActual = elemento.mapaZoom ?? 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Centro',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: latActual.toStringAsFixed(5),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Latitud',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) onLatChanged(parsed);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: lngActual.toStringAsFixed(5),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Longitud',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) onLngChanged(parsed);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Zoom: ${zoomActual.toStringAsFixed(1)}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Slider(
          value: zoomActual.clamp(1, 18),
          min: 1,
          max: 18,
          divisions: 34,
          onChanged: onZoomChanged,
        ),
        const SizedBox(height: 12),
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Etiquetas de clave catastral',
                style: const TextStyle(
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
      ],
    );
  }
}
