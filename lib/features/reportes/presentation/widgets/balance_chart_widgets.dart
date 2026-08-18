import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/import_normalization.dart' as norm;
import '../../../predios/models/predio.dart';
import '../../utils/balance_calculos.dart';

/// Widgets de gráfica de "Balance", extraídos de `balance_screen.dart`
/// como funciones libres (sin depender de `State`) para poder reutilizarse
/// también desde `GraficaWidget` (elemento `grafica` de Composiciones).

Widget buildKpiPanel({
  required String label,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.05)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.26)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF707780), height: 1.1),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: color, height: 1.0),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

Widget _ddvLegend(String label, Color color, String value, double pct) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 6),
      Text(
        '$label: $value (${(pct * 100).toStringAsFixed(1)}%)',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    ],
  );
}

Widget buildAvanceDdvStatusBar({
  required BuildContext context,
  required int total,
  required int liberado,
  required int noLiberado,
}) {
  final totalSafe = total <= 0 ? 1 : total;
  final pctLiber = (liberado / totalSafe).clamp(0.0, 1.0);
  final pctNoLib = (noLiberado / totalSafe).clamp(0.0, 1.0);
  final fmt = NumberFormat('#,##0', 'es_MX');

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Estatus DDV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text('${fmt.format(total)} predios', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                if (pctLiber > 0)
                  Expanded(
                    flex: (pctLiber * 100).round().clamp(1, 100),
                    child: Container(color: AppColors.secondary),
                  ),
                if (pctNoLib > 0)
                  Expanded(
                    flex: (pctNoLib * 100).round().clamp(1, 100),
                    child: Container(color: AppColors.warning),
                  ),
                if (pctLiber == 0 && pctNoLib == 0) Expanded(child: Container(color: AppColors.border)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _ddvLegend('Liberado', AppColors.secondary, fmt.format(liberado), pctLiber),
            _ddvLegend('No Liberado', AppColors.warning, fmt.format(noLiberado), pctNoLib),
          ],
        ),
      ],
    ),
  );
}

Widget buildLegendItem(String label, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ],
  );
}

/// Simbología compartida por "Avance por Segmento/Tramo/Frente", "Avance
/// Mensual" y "Avance Semanal": todas usan la misma convención de color
/// (verde = Liberado, rojo = No liberado).
Widget buildLiberadoLegend() {
  return Wrap(
    spacing: 16,
    children: [
      buildLegendItem('Liberado', AppColors.secondary),
      buildLegendItem('No liberado', AppColors.danger),
    ],
  );
}

Widget buildStackedPctBarra({
  required String label,
  required double pctLiberado,
  required double ancho,
  required double alto,
}) {
  final pct = pctLiberado.clamp(0.0, 100.0);
  final pctNoLiberado = 100 - pct;
  final flexLiberado = pct.round();
  final flexNoLiberado = pctNoLiberado.round();

  Widget segmento(double pctSegmento, Color color, int flex) {
    if (flex <= 0) return const SizedBox.shrink();
    final mostrarTexto = pctSegmento >= 8;
    return Expanded(
      flex: flex,
      child: Container(
        alignment: Alignment.center,
        color: color,
        child: mostrarTexto
            ? Text(
                '${pctSegmento.round()}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              )
            : null,
      ),
    );
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: ancho,
          height: alto,
          child: Column(
            children: [
              segmento(pctNoLiberado, AppColors.danger, flexNoLiberado),
              segmento(pct, AppColors.secondary, flexLiberado),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: ancho,
        child: Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

/// Fila horizontal desplazable de barras apiladas 0-100% (verde =
/// liberado, rojo = no liberado), una por cada entrada de `labels`/
/// `pctLiberadoPorBarra` (mismo índice).
Widget buildStackedPctBars({
  required List<String> labels,
  required List<double> pctLiberadoPorBarra,
  double anchoBarra = 56,
  double altoBarra = 190,
}) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          buildStackedPctBarra(
            label: labels[i],
            pctLiberado: i < pctLiberadoPorBarra.length ? pctLiberadoPorBarra[i] : 0,
            ancho: anchoBarra,
            alto: altoBarra,
          ),
          if (i < labels.length - 1) const SizedBox(width: 10),
        ],
      ],
    ),
  );
}

/// Bloque reutilizable "título + dona + leyenda" para desgloses por
/// categoría (Rango de Estatus, Tipo de Liberación).
/// `borderColorFn` es opcional: "Rango de Estatus" lo usa para distinguir
/// pares de categorías que comparten color de relleno.
Widget buildEstatusChartBlock({
  required String titulo,
  required List<MapEntry<String, int>> entries,
  required int total,
  required Color Function(String) colorFn,
  required NumberFormat fmtInt,
  Color Function(String)? borderColorFn,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sections: entries.map((e) {
                    final pct = total > 0 ? e.value / total * 100 : 0.0;
                    return PieChartSectionData(
                      color: colorFn(e.key),
                      value: e.value.toDouble(),
                      title: '${pct.toStringAsFixed(0)}%',
                      radius: 60,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    );
                  }).toList(),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: colorFn(e.key),
                                borderRadius: BorderRadius.circular(2),
                                border: borderColorFn != null
                                    ? Border.all(color: borderColorFn(e.key), width: 1.5)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${e.key}: ${fmtInt.format(e.value)}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget buildDonaSeparada({
  required String titulo,
  required int completado,
  required int total,
  required Color color,
  required IconData icon,
}) {
  if (total == 0) {
    return SizedBox(
      width: 112,
      child: Column(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.3), size: 24),
          const SizedBox(height: 6),
          SizedBox(
            width: 88,
            height: 88,
            child: PieChart(
              PieChartData(
                sectionsSpace: 1,
                centerSpaceRadius: 22,
                sections: [
                  PieChartSectionData(
                    color: color.withValues(alpha: 0.18),
                    value: 1,
                    title: '0',
                    radius: 22,
                    titleStyle: TextStyle(
                      color: color.withValues(alpha: 0.75),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            titulo,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const Text(
            '0 / 0',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  final restante = total - completado;
  final showGreySection = restante > 0 || completado == 0;

  return SizedBox(
    width: 112,
    child: Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        SizedBox(
          width: 88,
          height: 88,
          child: PieChart(
            PieChartData(
              sectionsSpace: 1,
              centerSpaceRadius: 22,
              sections: [
                PieChartSectionData(
                  color: color,
                  value: completado > 0 ? completado.toDouble() : 0.5,
                  title: completado.toString(),
                  radius: 22,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                if (showGreySection)
                  PieChartSectionData(
                    color: Colors.grey.shade300,
                    value: restante > 0 ? restante.toDouble() : 0.5,
                    title: '',
                    radius: 22,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          titulo,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        Text(
          '$completado / $total',
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

Widget buildTipoPropiedadCard({
  required String titulo,
  required List<Predio> predios,
  required NumberFormat fmtInt,
}) {
  final total = predios.length;
  final identificados = predios.where((p) => p.identificacion).length;
  final levantados = predios.where((p) => p.levantamiento).length;
  final negociados = predios.where((p) => p.negociacion).length;
  final liberados = predios.where((p) => p.cop).length;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.terrain, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text('Total de Predios: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      fmtInt.format(total),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildDonaSeparada(
              titulo: 'Identificación',
              completado: identificados,
              total: total,
              color: AppColors.info,
              icon: Icons.search,
            ),
            buildDonaSeparada(
              titulo: 'Levantamiento',
              completado: levantados,
              total: total,
              color: AppColors.warning,
              icon: Icons.architecture,
            ),
            buildDonaSeparada(
              titulo: 'Negociación',
              completado: negociados,
              total: total,
              color: AppColors.primary,
              icon: Icons.handshake,
            ),
            buildDonaSeparada(
              titulo: 'Liberados',
              completado: liberados,
              total: total,
              color: AppColors.secondary,
              icon: Icons.check_circle,
            ),
          ],
        ),
      ],
    ),
  );
}

Widget buildCadenamientoCelda(CadenamientoColumna columna, double ancho) {
  final color = colorParaPctLiberado(columna.pct);
  return SizedBox(
    width: ancho,
    child: Column(
      children: [
        SizedBox(
          height: 44,
          width: ancho,
          child: RotatedBox(
            quarterTurns: 3,
            child: Center(
              child: Text(
                norm.formatKmPk(columna.km.toDouble()),
                style: const TextStyle(fontSize: 8, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: ancho,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Text(
            '${(columna.pct * 100).round()}%',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    ),
  );
}

Widget buildCadenamientoFilaCard(CadenamientoFila fila) {
  const anchoCelda = 28.0;
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppColors.primaryDark,
          child: Text(
            '${fila.codigo}  ·  km ${norm.formatKmPk(fila.pkInicioKm)} a ${norm.formatKmPk(fila.pkFinKm)}  ·  '
            '${formatKmLength(fila.pkFinKm - fila.pkInicioKm)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        if (fila.columnas.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Sin predios con Km Inicio/Km Fin registrados para este PK.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                for (final columna in fila.columnas) ...[
                  buildCadenamientoCelda(columna, anchoCelda),
                  const SizedBox(width: 2),
                ],
              ],
            ),
          ),
      ],
    ),
  );
}
