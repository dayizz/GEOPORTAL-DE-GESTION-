import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';

String _etiquetaTipoGrafica(TipoGrafica tipo) {
  switch (tipo) {
    case TipoGrafica.kpiPanel:
      return 'KPIs (avance de proyecto)';
    case TipoGrafica.avanceDdv:
      return 'Avance DDV';
    case TipoGrafica.rangoEstatus:
      return 'Rango de estatus';
    case TipoGrafica.tipoLiberacion:
      return 'Tipo de liberación';
    case TipoGrafica.tipoPropiedad:
      return 'Avance por tipo de propiedad';
    case TipoGrafica.segmentoTramoFrente:
      return 'Avance por segmento/tramo/frente';
    case TipoGrafica.cadenamiento:
      return 'Diagrama por cadenamiento';
    case TipoGrafica.avanceMensual:
      return 'Avance mensual';
    case TipoGrafica.avanceSemanal:
      return 'Avance semanal';
  }
}

/// Panel de propiedades para [TipoElemento.grafica]: elegir el tipo de
/// gráfica de "Balance" a mostrar. El proyecto ya está fijo al proyecto de
/// la composición (igual que el elemento de mapa), así que solo hace
/// falta elegir el tipo.
class PanelPropiedadesGrafica extends StatelessWidget {
  const PanelPropiedadesGrafica({
    super.key,
    required this.elemento,
    required this.onTipoChanged,
  });

  final ElementoComposicion elemento;
  final ValueChanged<TipoGrafica> onTipoChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo de gráfica', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<TipoGrafica>(
          initialValue: elemento.graficaTipo ?? TipoGrafica.kpiPanel,
          isDense: true,
          isExpanded: true,
          items: TipoGrafica.values
              .map((t) => DropdownMenuItem(value: t, child: Text(_etiquetaTipoGrafica(t), style: const TextStyle(fontSize: 12))))
              .toList(),
          onChanged: (v) {
            if (v != null) onTipoChanged(v);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Proyecto: ${elemento.graficaProyecto?.isNotEmpty == true ? elemento.graficaProyecto : "(sin proyecto)"}',
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}
