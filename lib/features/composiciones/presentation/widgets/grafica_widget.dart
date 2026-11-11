import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../estructura/models/proyecto_item.dart';
import '../../../predios/models/predio.dart';
import '../../../reportes/presentation/widgets/balance_chart_widgets.dart';
import '../../../reportes/utils/balance_calculos.dart';
import '../../../reportes/utils/resumen_tramos.dart';
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
///
/// El contenido se dibuja a un ancho fijo de diseño ([anchoDiseno]) y se
/// escala para llenar el ancho del elemento, así se ve igual en el editor
/// y al exportar, a cualquier tamaño. [onAspecto] informa alto/ancho del
/// contenido para que el editor ajuste el alto del elemento y no queden
/// espacios vacíos.
class GraficaWidget extends StatelessWidget {
  const GraficaWidget({
    super.key,
    required this.tipo,
    required this.predios,
    this.proyectoItem,
    this.segmento,
    this.fondo = Colors.white,
    this.onAspecto,
  });

  final TipoGrafica tipo;
  final List<Predio> predios;
  final ProyectoItem? proyectoItem;
  // Segmento del filtro, para limitar las filas del cadenamiento.
  final String? segmento;
  final Color? fondo;
  final ValueChanged<double>? onAspecto;

  bool get _conFondo => fondo != null;

  // Barras de `buildStackedPctBars`: 56 px de ancho + 10 de separación.
  static double _anchoBarras(int n) => n * 56.0 + (n - 1) * 10;

  /// Ancho de diseño: lo suficiente para que las filas de barras y el
  /// cadenamiento -que en Balance se desplazan horizontalmente- quepan
  /// completas, ya que en una hoja no hay desplazamiento y se cortarían.
  double _anchoDiseno() {
    const relleno = 12.0;
    final double contenido = switch (tipo) {
      TipoGrafica.kpiPanel => 328,
      TipoGrafica.avanceMensual => _anchoBarras(sparkMonths),
      TipoGrafica.avanceSemanal => _anchoBarras(sparkWeeks),
      TipoGrafica.segmentoTramoFrente => _anchoBarras(groupCountBy(predios, (p) => p.tramo).length),
      // Celdas de 28 px + 2 de separación, más relleno y borde de la tarjeta.
      TipoGrafica.cadenamiento => _filasCadenamiento().fold<double>(
          0, (m, f) => math.max(m, f.columnas.length * 30.0 + 22)),
      _ => 0,
    };
    return math.max(tipo == TipoGrafica.cadenamiento ? 440 : 380, contenido + relleno);
  }

  List<CadenamientoFila> _filasCadenamiento() => buildFilasCadenamiento(proyectoItem, predios)
      .where((fila) => segmento == null ||
          claveTramoBalance(fila.codigo, proyectoItem) == claveTramoBalance(segmento!, proyectoItem))
      .toList();

  @override
  Widget build(BuildContext context) {
    final ancho = _anchoDiseno();
    return Container(
      color: fondo,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: ancho,
          child: _ReportarTamano(
            onTamano: (s) => onAspecto?.call(s.height / ancho),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: _contenido(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    final fmtInt = NumberFormat('#,##0', 'es_MX');
    final total = predios.length;

    if (total == 0 && tipo != TipoGrafica.cadenamiento) {
      return  Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
          conFondo: _conFondo,
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
            buildTipoPropiedadCard(titulo: 'Propiedad Privada', predios: prediosPrivada, fmtInt: fmtInt, conFondo: _conFondo),
            const SizedBox(height: 12),
            buildTipoPropiedadCard(
              titulo: 'Propiedad social/Dominio pleno',
              predios: prediosSocialDominio,
              fmtInt: fmtInt,
              conFondo: _conFondo,
            ),
          ],
        );
        break;
      case TipoGrafica.tipoPropiedadPrivada:
        content = buildTipoPropiedadCard(
          titulo: 'Propiedad Privada',
          predios: predios.where((p) => p.tipoPropiedad.toUpperCase() == 'PRIVADA').toList(),
          fmtInt: fmtInt,
          conFondo: _conFondo,
        );
        break;
      case TipoGrafica.tipoPropiedadSocial:
        content = buildTipoPropiedadCard(
          titulo: 'Propiedad social/Dominio pleno',
          predios: predios
              .where((p) =>
                  p.tipoPropiedad.toUpperCase() == 'SOCIAL' || p.tipoPropiedad.toUpperCase() == 'DOMINIO PLENO')
              .toList(),
          fmtInt: fmtInt,
          conFondo: _conFondo,
        );
        break;
      case TipoGrafica.segmentoTramoFrente:
        final porTramo = groupCountBy(predios, (p) => p.tramo);
        content = porTramo.isEmpty
            ?  Text('Sin datos de tramos para este proyecto', style: TextStyle(color: AppColors.textSecondary))
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
        final filas = _filasCadenamiento();
        content = filas.isEmpty
            ?  Text(
                'Sin cadenamiento registrado para este proyecto.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final fila in filas) ...[
                    buildCadenamientoFilaCard(fila, conFondo: _conFondo),
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

    return content;
  }

  Widget _buildKpiGrid(NumberFormat fmtInt, int total) {
    final liberados = predios.where((p) => p.cop).length;
    final noLiberados = (total - liberados).clamp(0, total);
    final kmEfectivos = predios.where((p) => p.cop).fold<double>(0, (sum, p) => sum + (p.kmEfectivos ?? 0));

    final cards = [
      buildKpiPanel(label: 'Total Predios', value: fmtInt.format(total), color: AppColors.primary, icon: Icons.terrain_outlined, conFondo: _conFondo),
      buildKpiPanel(
          label: 'Km Efectivos Liberados', value: fmtInt.format(kmEfectivos), color: AppColors.secondary, icon: Icons.straighten, conFondo: _conFondo),
      buildKpiPanel(
          label: 'Predios Liberados', value: fmtInt.format(liberados), color: AppColors.secondary, icon: Icons.check_circle_outline, conFondo: _conFondo),
      buildKpiPanel(
          label: 'Pendiente Liberar', value: fmtInt.format(noLiberados), color: AppColors.warning, icon: Icons.pending_outlined, conFondo: _conFondo),
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

/// Informa el tamaño de su hijo tras cada layout en que cambie (después
/// del frame, para no provocar setState durante el build del editor).
class _ReportarTamano extends SingleChildRenderObjectWidget {
  const _ReportarTamano({required this.onTamano, super.child});
  final ValueChanged<Size> onTamano;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderReportarTamano(onTamano);

  @override
  void updateRenderObject(BuildContext context, _RenderReportarTamano renderObject) {
    renderObject.onTamano = onTamano;
  }
}

class _RenderReportarTamano extends RenderProxyBox {
  _RenderReportarTamano(this.onTamano);
  ValueChanged<Size> onTamano;
  Size? _ultimo;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _ultimo) return;
    _ultimo = size;
    final tamano = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onTamano(tamano));
  }
}
