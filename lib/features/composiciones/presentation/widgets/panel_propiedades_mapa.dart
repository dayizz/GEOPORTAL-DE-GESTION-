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
    required this.onBaseLayerChanged,
    required this.onMostrarClavesChanged,
  });

  final ElementoComposicion elemento;
  final ValueChanged<String> onBaseLayerChanged;
  final ValueChanged<bool> onMostrarClavesChanged;

  @override
  Widget build(BuildContext context) {
    final baseLayerActual = elemento.mapaBaseLayer ?? 'estandar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo de mapa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: baseLayerActual,
          isDense: true,
          items: _opcionesBaseLayer
              .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2, style: const TextStyle(fontSize: 12))))
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
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
