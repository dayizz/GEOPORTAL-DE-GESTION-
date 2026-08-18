import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';

/// Panel de propiedades para [TipoElemento.escala]: elegir a qué mapa de
/// la misma hoja se asocia (de ahí se deriva la relación metros/mm).
class PanelPropiedadesEscala extends StatelessWidget {
  const PanelPropiedadesEscala({
    super.key,
    required this.elemento,
    required this.mapasDisponibles,
    required this.onMapaIdChanged,
  });

  final ElementoComposicion elemento;
  final List<ElementoComposicion> mapasDisponibles;
  final ValueChanged<String?> onMapaIdChanged;

  @override
  Widget build(BuildContext context) {
    if (mapasDisponibles.isEmpty) {
      return const Text(
        'Agrega un elemento de mapa a esta hoja para poder asociarle una escala.',
        style: TextStyle(fontSize: 11, color: Colors.black54),
      );
    }
    final valorValido = mapasDisponibles.any((m) => m.id == elemento.escalaMapaId) ? elemento.escalaMapaId : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mapa asociado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: valorValido,
          isDense: true,
          hint: const Text('Selecciona un mapa', style: TextStyle(fontSize: 12)),
          items: mapasDisponibles
              .map((m) => DropdownMenuItem(value: m.id, child: Text(m.nombreCapa)))
              .toList(),
          onChanged: onMapaIdChanged,
        ),
      ],
    );
  }
}
