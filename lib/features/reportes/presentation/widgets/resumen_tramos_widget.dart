import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../utils/resumen_tramos.dart';
import '../../utils/balance_calculos.dart';

class ResumenTramosWidget extends StatelessWidget {
  final List<ResumenTramoBalance> filas;
  final bool usaM2;
  const ResumenTramosWidget({
    super.key,
    required this.filas,
    this.usaM2 = false,
  });

  @override
  Widget build(BuildContext context) {
    final unidad = usaM2 ? 'm²' : 'km';
    double? total(ResumenTramoBalance f) => usaM2
        ? f.predios.fold<double>(
            0,
            (s, p) => s + medidaPredioBalance(p, usaM2: true),
          )
        : f.longitud;
    double liberado(ResumenTramoBalance f) => usaM2
        ? f.predios
              .where(predioEstaLiberado)
              .fold<double>(
                0,
                (s, p) => s + medidaPredioBalance(p, usaM2: true),
              )
        : f.kmLiberados;
    double? porcentaje(ResumenTramoBalance f) =>
        (total(f) ?? 0) > 0 ? liberado(f) / total(f)! * 100 : null;
    final fmt = NumberFormat('#,##0.###', 'es_MX');
    String formatMedida(double? value) =>
        value == null ? '—' : fmt.format(value);
    String pct(double? value) => value == null
        ? usaM2
              ? 'Sin superficie'
              : 'Sin longitud'
        : '${fmt.format(value)}%';
    if (filas.isEmpty)
      return const Text('Sin datos de T/F/S para la selección actual.');
    final detalleMunicipios = usaM2
        ? resumenMunicipioInfraestructuraBalance(filas)
        : const <ResumenMunicipioInfraestructuraBalance>[];
    final columnas = <DataColumn>[
      DataColumn(
        label: Text(
          'T/F/S',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      if (usaM2) ...[
        DataColumn(
          label: Text(
            'Municipio',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Tipo de infraestructura',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ] else ...[
        DataColumn(
          label: Text(
            'Km inicio',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Km fin',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
      DataColumn(
        label: Text(
          usaM2 ? 'Superficie total (m²)' : 'Longitud (km)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      for (final titulo in [
        'Predios\nclasificados',
        'Predios\nliberados',
        '$unidad liberados',
        'Avance ($unidad) %',
      ])
        DataColumn(
          label: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
    ];
    final filasTabla = usaM2
        ? [
            for (final detalle in detalleMunicipios)
              DataRow(
                cells: [
                  DataCell(Text(detalle.codigoTramo)),
                  DataCell(Text(detalle.municipio)),
                  DataCell(Text(detalle.tipoInfraestructura)),
                  DataCell(Text(formatMedida(detalle.superficieTotal))),
                  DataCell(Text('${detalle.predios.length}')),
                  DataCell(Text('${detalle.liberados}')),
                  DataCell(Text(formatMedida(detalle.superficieLiberada))),
                  DataCell(Text(pct(detalle.porcentaje))),
                ],
              ),
          ]
        : [
            for (final fila in filas)
              DataRow(
                cells: [
                  DataCell(Text(fila.codigo)),
                  DataCell(Text(formatMedida(fila.inicio))),
                  DataCell(Text(formatMedida(fila.fin))),
                  DataCell(Text(formatMedida(total(fila)))),
                  DataCell(Text('${fila.predios.length}')),
                  DataCell(Text('${fila.liberados}')),
                  DataCell(Text(formatMedida(liberado(fila)))),
                  DataCell(Text(pct(porcentaje(fila)))),
                ],
              ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          usaM2
              ? 'Avance de m² = superficie de registros liberados / superficie total × 100.'
              : 'Avance de km = km efectivos liberados / longitud del cadenamiento × 100.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(1350.0, constraints.maxWidth),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: DataTable(
                      columnSpacing: 12,
                      horizontalMargin: 8,
                      headingRowHeight: 64,
                      columns: columnas,
                      rows: filasTabla,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          '$unidad liberados por T/F/S',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        for (final f in filas)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${f.codigo}: ${formatMedida(liberado(f))} $unidad · ${pct(porcentaje(f))}',
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: ((porcentaje(f) ?? 0) / 100).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  minHeight: 16,
                                  color: AppColors.secondary,
                                  backgroundColor: AppColors.border,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!usaM2 && filas.any((f) => f.longitud == null))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Sin longitud: completa un cadenamiento válido en Estructura para calcular el porcentaje.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }
}
