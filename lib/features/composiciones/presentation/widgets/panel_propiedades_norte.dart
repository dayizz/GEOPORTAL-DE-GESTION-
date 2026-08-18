import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';

/// Panel de propiedades para [TipoElemento.norte]: solo la rotación
/// (orientación de la flecha), el único ajuste relevante para este tipo.
class PanelPropiedadesNorte extends StatelessWidget {
  const PanelPropiedadesNorte({
    super.key,
    required this.elemento,
    required this.onRotacionChanged,
  });

  final ElementoComposicion elemento;
  final ValueChanged<double> onRotacionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Orientación: ${elemento.rotacion.round()}°',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        Slider(
          value: elemento.rotacion.clamp(0, 360),
          min: 0,
          max: 360,
          onChanged: onRotacionChanged,
        ),
      ],
    );
  }
}
