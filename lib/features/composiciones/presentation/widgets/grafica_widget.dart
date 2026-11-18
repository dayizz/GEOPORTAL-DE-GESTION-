import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../estructura/models/proyecto_item.dart';
import '../../../predios/models/predio.dart';
import '../../../reportes/presentation/widgets/avance_general_widget.dart';
import '../../../reportes/presentation/widgets/balance_chart_widgets.dart';
import '../../../../core/utils/import_normalization.dart' as norm;
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
    this.registros,
    this.grupo = GrupoInfraestructuraBalance.predios,
    this.proyectoItem,
    this.segmento,
    this.fondo = Colors.white,
    this.fuente,
    this.onAspecto,
  });

  final TipoGrafica tipo;
  final List<Predio> predios;
  // Registros del segmento en todos los grupos de infraestructura (lo que
  // Balance llama `registrosFiltrados`), base del "Avance general".
  final List<Predio>? registros;
  // Grupo "Ver como" del filtro, que define qué tarjetas muestra el KPI.
  final GrupoInfraestructuraBalance grupo;
  final ProyectoItem? proyectoItem;
  // Segmento del filtro, para limitar las filas del cadenamiento.
  final String? segmento;
  final Color? fondo;
  // Tipo de letra de todos los textos de la gráfica; null = predeterminado.
  final String? fuente;
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
      // Mismo ancho mínimo que usa `AvanceGeneralWidget` en Balance.
      TipoGrafica.kpiPanel => grupo == GrupoInfraestructuraBalance.predios ? 1100 : 880,
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
              child: _conFuente(Builder(builder: _contenido)),
            ),
          ),
        ),
      ),
    );
  }

  /// Aplica [fuente] a los textos de la gráfica (los estilos de los
  /// gráficos de Balance heredan la familia del `DefaultTextStyle`).
  Widget _conFuente(Widget child) {
    final f = fuente;
    if (f == null || f.isEmpty) return child;
    final estilo = f == 'Arial' || !GoogleFonts.asMap().containsKey(f)
        ? TextStyle(fontFamily: f)
        : GoogleFonts.getFont(f);
    return DefaultTextStyle.merge(
      style: TextStyle(fontFamily: estilo.fontFamily, fontFamilyFallback: estilo.fontFamilyFallback),
      child: child,
    );
  }

  Widget _contenido(BuildContext context) {
    final fmtInt = NumberFormat('#,##0', 'es_MX');
    final total = predios.length;

    if (total == 0 && tipo != TipoGrafica.cadenamiento && tipo != TipoGrafica.kpiPanel) {
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
        content = _buildAvanceGeneral(fmtInt);
        break;
      case TipoGrafica.avanceDdv:
        // Mismo criterio que Balance: liberado según `predioEstaLiberado`
        // y la negociación separada de los no liberados.
        final liberados = predios.where(predioEstaLiberado).length;
        final negociacion = predios.where((p) =>
            norm.stripAccents(p.rangoEstatus).trim().toUpperCase() == 'NEGOCIACION').length;
        final noLiberados = (total - liberados).clamp(0, total);
        content = buildAvanceDdvStatusBar(
          context: context,
          total: total,
          liberado: liberados,
          noLiberado: noLiberados - negociacion,
          negociacion: negociacion,
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

  /// "Avance general" de Balance: mismas tarjetas y cálculos
  /// (`AvanceGeneralBalance`) sobre los registros del segmento.
  Widget _buildAvanceGeneral(NumberFormat fmtInt) {
    final registros = this.registros ?? predios;
    final grupos = agruparInfraestructuraBalance(registros);
    final enInvestigacion = grupos[GrupoInfraestructuraBalance.nulos]!.length +
        grupos[GrupoInfraestructuraBalance.sinAfectacion]!.length +
        grupos[GrupoInfraestructuraBalance.otros]!.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvanceGeneralWidget(avance: AvanceGeneralBalance(registros), grupo: grupo, conFondo: _conFondo),
        if (grupo == GrupoInfraestructuraBalance.predios) ...[
          const SizedBox(height: 8),
          Text(
            'Total de registros en investigación: ${fmtInt.format(enInvestigacion)}',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
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
