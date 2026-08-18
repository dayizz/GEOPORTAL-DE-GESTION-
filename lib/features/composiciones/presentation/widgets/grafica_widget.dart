import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../estructura/models/proyecto_item.dart';
import '../../../predios/models/predio.dart';
import '../../../reportes/presentation/widgets/balance_chart_widgets.dart';
import '../../../reportes/utils/balance_calculos.dart';
import '../../models/elemento_composicion.dart';

/// Render de una gráfica de "Balance" dentro de una composición,
/// reutilizando las mismas funciones de cálculo/dibujo que `BalanceScreen`
/// (ver `balance_calculos.dart`/`balance_chart_widgets.dart`) para no
/// duplicar esa lógica en dos lugares.
///
/// [predios] ya viene resuelto y filtrado por el proyecto del elemento
/// (ver el comentario en `MapaViewportWidget` sobre por qué no se resuelve
/// aquí mismo vía Riverpod). [proyectoItem] solo se usa para
/// [TipoGrafica.cadenamiento] (necesita el cadenamiento capturado en
/// Estructura > Proyectos).
class GraficaWidget extends StatelessWidget {
  const GraficaWidget({
    super.key,
    required this.tipo,
    required this.predios,
    this.proyectoItem,
  });

  final TipoGrafica tipo;
  final List<Predio> predios;
  final ProyectoItem? proyectoItem;

  @override
  Widget build(BuildContext context) {
    final fmtInt = NumberFormat('#,##0', 'es_MX');
    final total = predios.length;

    if (total == 0 && tipo != TipoGrafica.cadenamiento) {
      return const Center(
        child: Text(
          'Sin predios para este proyecto',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      );
    }

    final Widget content;
    switch (tipo) {
      case TipoGrafica.kpiPanel:
        content = _buildKpiGrid(fmtInt, total);
        break;
      case TipoGrafica.avanceDdv:
        final liberados = predios.where((p) => p.cop).length;
        final noLiberados = (total - liberados).clamp(0, total);
        content = buildAvanceDdvStatusBar(
          context: context,
          total: total,
          liberado: liberados,
          noLiberado: noLiberados,
        );
        break;
      case TipoGrafica.rangoEstatus:
        final porRango = ordenarRangoEstatus(groupCountBy(predios, (p) => p.rangoEstatus));
        content = buildEstatusChartBlock(
          titulo: 'Rango de Estatus',
          entries: porRango,
          total: total,
          colorFn: AppColors.rangoEstatusColor,
          borderColorFn: AppColors.rangoEstatusBorderColor,
          fmtInt: fmtInt,
        );
        break;
      case TipoGrafica.tipoLiberacion:
        final porTipo = porTipoLiberacionConsolidado(predios);
        content = buildEstatusChartBlock(
          titulo: 'Tipo de Liberación',
          entries: porTipo.entries.toList(),
          total: porTipo.values.fold(0, (a, b) => a + b),
          colorFn: tipoLiberacionColor,
          fmtInt: fmtInt,
        );
        break;
      case TipoGrafica.tipoPropiedad:
        final prediosPrivada = predios.where((p) => p.tipoPropiedad.toUpperCase() == 'PRIVADA').toList();
        final prediosSocialDominio = predios
            .where((p) =>
                p.tipoPropiedad.toUpperCase() == 'SOCIAL' || p.tipoPropiedad.toUpperCase() == 'DOMINIO PLENO')
            .toList();
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildTipoPropiedadCard(titulo: 'Propiedad Privada', predios: prediosPrivada, fmtInt: fmtInt),
            const SizedBox(height: 12),
            buildTipoPropiedadCard(
              titulo: 'Propiedad social/Dominio pleno',
              predios: prediosSocialDominio,
              fmtInt: fmtInt,
            ),
          ],
        );
        break;
      case TipoGrafica.segmentoTramoFrente:
        final porTramo = groupCountBy(predios, (p) => p.tramo);
        content = porTramo.isEmpty
            ? const Text('Sin datos de tramos para este proyecto', style: TextStyle(color: AppColors.textSecondary))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLiberadoLegend(),
                  const SizedBox(height: 10),
                  buildStackedPctBars(
                    labels: porTramo.keys.toList(),
                    pctLiberadoPorBarra: pctLiberadoPorTramo(porTramo, predios),
                  ),
                ],
              );
        break;
      case TipoGrafica.cadenamiento:
        final filas = buildFilasCadenamiento(proyectoItem, predios);
        content = filas.isEmpty
            ? const Text(
                'Sin cadenamiento registrado para este proyecto.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final fila in filas) ...[
                    buildCadenamientoFilaCard(fila),
                    const SizedBox(height: 10),
                  ],
                ],
              );
        break;
      case TipoGrafica.avanceMensual:
        final pct = cumulativePctLiberado(
          predios,
          finesDePeriodo: List.generate(sparkMonths, (i) {
            final now = DateTime.now();
            final mes = DateTime(now.year, now.month - (sparkMonths - 1 - i));
            return DateTime(mes.year, mes.month + 1, 1);
          }),
        );
        final labels = List.generate(sparkMonths, (i) {
          final now = DateTime.now();
          final mes = DateTime(now.year, now.month - (sparkMonths - 1 - i));
          return mesAbrev[mes.month - 1];
        });
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildLiberadoLegend(),
            const SizedBox(height: 10),
            buildStackedPctBars(labels: labels, pctLiberadoPorBarra: pct),
          ],
        );
        break;
      case TipoGrafica.avanceSemanal:
        final pct = cumulativePctLiberado(
          predios,
          finesDePeriodo: List.generate(sparkWeeks, (i) => weekStart(i).add(const Duration(days: 7))),
        );
        final labels = List.generate(sparkWeeks, (i) => DateFormat('d/MM').format(weekStart(i)));
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildLiberadoLegend(),
            const SizedBox(height: 10),
            buildStackedPctBars(labels: labels, pctLiberadoPorBarra: pct),
          ],
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      color: Colors.white,
      child: SingleChildScrollView(child: content),
    );
  }

  Widget _buildKpiGrid(NumberFormat fmtInt, int total) {
    final liberados = predios.where((p) => p.cop).length;
    final noLiberados = (total - liberados).clamp(0, total);
    final kmEfectivos = predios.where((p) => p.cop).fold<double>(0, (sum, p) => sum + (p.kmEfectivos ?? 0));

    final cards = [
      buildKpiPanel(label: 'Total Predios', value: fmtInt.format(total), color: AppColors.primary, icon: Icons.terrain_outlined),
      buildKpiPanel(
          label: 'Km Efectivos Liberados', value: fmtInt.format(kmEfectivos), color: AppColors.secondary, icon: Icons.straighten),
      buildKpiPanel(
          label: 'Predios Liberados', value: fmtInt.format(liberados), color: AppColors.secondary, icon: Icons.check_circle_outline),
      buildKpiPanel(
          label: 'Pendiente Liberar', value: fmtInt.format(noLiberados), color: AppColors.warning, icon: Icons.pending_outlined),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: SizedBox(height: 66, child: cards[0])),
            const SizedBox(width: 6),
            Expanded(child: SizedBox(height: 66, child: cards[1])),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: SizedBox(height: 66, child: cards[2])),
            const SizedBox(width: 6),
            Expanded(child: SizedBox(height: 66, child: cards[3])),
          ],
        ),
      ],
    );
  }
}
