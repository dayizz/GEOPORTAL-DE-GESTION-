import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';

String _etiquetaTipoSimbologia(TipoSimbologia tipo) {
  switch (tipo) {
    case TipoSimbologia.estatus:
      return 'Estatus';
    case TipoSimbologia.rangoEstatus:
      return 'Rango de estatus';
    case TipoSimbologia.tipoPropiedad:
      return 'Tipo de propiedad';
  }
}

/// Panel de propiedades para [TipoElemento.simbologia]: elegir el modo
/// (estatus, rango de estatus o tipo de propiedad).
class PanelPropiedadesSimbologia extends StatelessWidget {
  const PanelPropiedadesSimbologia({
    super.key,
    required this.elemento,
    required this.onTipoChanged,
  });

  final ElementoComposicion elemento;
  final ValueChanged<TipoSimbologia> onTipoChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Simbología por', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<TipoSimbologia>(
          initialValue: elemento.simbologiaTipo ?? TipoSimbologia.estatus,
          isDense: true,
          items: TipoSimbologia.values
              .map((t) => DropdownMenuItem(value: t, child: Text(_etiquetaTipoSimbologia(t))))
              .toList(),
          onChanged: (v) {
            if (v != null) onTipoChanged(v);
          },
        ),
      ],
    );
  }
}
