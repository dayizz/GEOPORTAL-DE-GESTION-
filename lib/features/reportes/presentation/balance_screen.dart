import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../features/predios/providers/predios_provider.dart';
import '../../../features/predios/models/predio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class BalanceScreen extends ConsumerStatefulWidget {
  const BalanceScreen({super.key});

  @override
  ConsumerState<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends ConsumerState<BalanceScreen> {
  static const _proyectos = ['TQI', 'TSNL', 'TAP', 'TQM'];
  static const _sparkMonths = 6;

  String _proyectoActual = 'TQI';
  String? _segmentoActual;
  List<String> _segmentos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(prediosMapaProvider);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.invalidate(prediosMapaProvider);
  }

  String _predioProyecto(Predio predator) {
    final proyectoDirecto = predator.proyecto?.trim().toUpperCase();
    if (proyectoDirecto != null && _proyectos.contains(proyectoDirecto)) {
      return proyectoDirecto;
    }

    final clave = predator.claveCatastral.trim().toUpperCase();
    final compact = clave.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.startsWith('TQI') || compact.startsWith('QI')) return 'TQI';
    if (compact.startsWith('TSNL') || compact.startsWith('SNL') || compact.startsWith('SL')) return 'TSNL';
    if (compact.startsWith('TAP') || compact.startsWith('AP')) return 'TAP';
    if (compact.startsWith('TQM') || compact.startsWith('QM')) return 'TQM';

    final contenido = [
      predator.claveCatastral,
      predator.ejido ?? '',
      predator.poligonoDwg ?? '',
      predator.oficio ?? '',
      predator.copFirmado ?? '',
    ].join(' ').toUpperCase();

    for (final proyecto in _proyectos) {
      if (contenido.contains(proyecto)) return proyecto;
    }

    return 'Sin proyecto';
  }

  Map<String, int> _groupCountBy<T>(Iterable<Predio> predios, T Function(Predio) selector) {
    final result = <String, int>{};
    for (final predator in predios) {
      final key = selector(predator).toString();
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  DateTime _monthKey(DateTime date) => DateTime(date.year, date.month);

  List<double> _monthlySeries({
    required List<Predio> predios,
    required DateTime? Function(Predio) dateSelector,
    required double Function(Predio) valueSelector,
  }) {
    final now = DateTime.now();
    final months = List.generate(
      _sparkMonths,
      (i) => DateTime(now.year, now.month - (_sparkMonths - 1 - i)),
    );
    final monthValues = <DateTime, double>{
      for (final month in months) _monthKey(month): 0,
    };

    for (final predator in predios) {
      final date = dateSelector(predator);
      if (date == null) continue;
      final key = _monthKey(date);
      if (!monthValues.containsKey(key)) continue;
      monthValues[key] = (monthValues[key] ?? 0) + valueSelector(predator);
    }

    return months.map((month) => monthValues[_monthKey(month)] ?? 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    final prediosAsync = ref.watch(prediosMapaProvider);
    final fmtInt = NumberFormat('#,##0', 'es_MX');
    final canAllProjects = ref.watch(canAccessAllProjectsProvider);
    final proyectosAsignados = ref.watch(currentUserAssignedProjectsProvider);
    final sinProyectoAsignado = !canAllProjects && proyectosAsignados.isEmpty;

    if (sinProyectoAsignado) {
      return AppScaffold(
        currentIndex: 1,
        title: 'Balance',
        child: const Center(
          child: Text(
            'Sin proyecto asignado',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    final proyectosDisponibles = canAllProjects
        ? _proyectos
        : _proyectos.where(proyectosAsignados.contains).toList(growable: false);
    final proyectoActivo = proyectosDisponibles.contains(_proyectoActual)
        ? _proyectoActual
        : proyectosDisponibles.first;
    if (proyectoActivo != _proyectoActual) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _proyectoActual = proyectoActivo);
      });
    }

    return AppScaffold(
      currentIndex: 1,
      title: 'Balance  •  $proyectoActivo',
      child: prediosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(e.toString()),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(prediosMapaProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (predios) {
          final proyectoPredios = predios
              .where((predator) => _predioProyecto(predator) == proyectoActivo)
              .toList();
          
          // Extraer segmentos únicos del proyecto
          final segmentos = proyectoPredios
              .where((p) => p.tramo.isNotEmpty)
              .map((p) => p.tramo)
              .toSet()
              .toList();
          segmentos.sort();
          
          // Actualizar la lista de segmentos si cambió el proyecto
          if (_segmentos.isEmpty || _segmentos.length != segmentos.length || 
              (!_segmentoActualExists(segmentos))) {
            _segmentos = segmentos;
            if (_segmentoActual != null && !segmentos.contains(_segmentoActual)) {
              _segmentoActual = null;
            }
          }

          // Filtrar por segmento si hay uno seleccionado
          final prediosFiltrados = _segmentoActual != null
              ? proyectoPredios.where((p) => p.tramo == _segmentoActual).toList()
              : proyectoPredios;

          final total = prediosFiltrados.length;
          final porTramo = _groupCountBy(prediosFiltrados, (predator) => predator.tramo);
          
          final prediosLiberados = prediosFiltrados.where((predator) => predator.cop).length;
          final prediosNoLiberados = (total - prediosLiberados).clamp(0, total);
          
          final kmEfectivosLiberados = prediosFiltrados
              .where((predator) => predator.cop)
              .fold<double>(0, (sum, predator) => sum + (predator.kmEfectivos ?? 0));
          
          // Agrupar por tipo de liberación usando primero el valor capturado en Gestión.
          final porTipoLiberacion = <String, int>{};
          for (final predio in prediosFiltrados) {
            final tipo = _resolveTipoLiberacion(predio);
            porTipoLiberacion[tipo] = (porTipoLiberacion[tipo] ?? 0) + 1;
          }

          // Consolidar "Sin tipo" y "Sin liberación" en una sola categoría.
          final sinTipo = porTipoLiberacion.remove('Sin tipo') ?? 0;
          final sinLiberacion = porTipoLiberacion.remove('Sin liberación') ?? 0;
          final sinTipoSinLiberacion = sinTipo + sinLiberacion;
          if (sinTipoSinLiberacion > 0) {
            porTipoLiberacion['Sin tipo / Sin liberación'] = sinTipoSinLiberacion;
          }

          final prediosPrivada = prediosFiltrados.where((p) => p.tipoPropiedad.toUpperCase() == 'PRIVADA').toList();
          final prediosSocialDominio = prediosFiltrados
              .where((p) => p.tipoPropiedad.toUpperCase() == 'SOCIAL' || p.tipoPropiedad.toUpperCase() == 'DOMINIO PLENO')
              .toList();

          final monthlyLiberados = _monthlySeries(
            predios: prediosFiltrados.where((p) => p.cop).toList(),
            dateSelector: (p) => p.copFecha ?? p.updatedAt ?? p.createdAt,
            valueSelector: (_) => 1,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Proyecto:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
                      ),
                      const SizedBox(width: 10),
                      DropdownButtonHideUnderline(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFDCDCDC)),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: DropdownButton<String>(
                            value: proyectoActivo,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9A9A9A)),
                            style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
                            items: proyectosDisponibles
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _proyectoActual = v;
                                  _segmentoActual = null;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text('Avance de Proyecto', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      _buildKpiPanel(
                        label: 'Total Predios',
                        value: fmtInt.format(total),
                        color: AppColors.primary,
                        icon: Icons.terrain_outlined,
                      ),
                      _buildKpiPanel(
                        label: 'Km Efectivos Liberados',
                        value: fmtInt.format(kmEfectivosLiberados),
                        color: AppColors.secondary,
                        icon: Icons.straighten,
                      ),
                      _buildKpiPanel(
                        label: 'Predios Liberados',
                        value: fmtInt.format(prediosLiberados),
                        color: AppColors.secondary,
                        icon: Icons.check_circle_outline,
                      ),
                      _buildKpiPanel(
                        label: 'Pendiente Liberar',
                        value: fmtInt.format(prediosNoLiberados),
                        color: AppColors.warning,
                        icon: Icons.pending_outlined,
                      ),
                    ];

                    final isWide = constraints.maxWidth >= 920;
                    if (isWide) {
                      return SizedBox(
                        height: 96,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              Expanded(child: cards[i]),
                              if (i < cards.length - 1) const SizedBox(width: 12),
                            ],
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 12),
                            Expanded(child: cards[1]),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: cards[2]),
                            const SizedBox(width: 12),
                            Expanded(child: cards[3]),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),
                // Barra de Avance DDV - extendida en toda la fila
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Avance DDV', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            if (total == 0)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'No hay predios cargados para este proyecto',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                    ),
                                  ],
                                ),
                              )
                            else
                              _buildAvanceDdvStatusBar(
                                context: context,
                                total: total,
                                liberado: prediosLiberados,
                                noLiberado: prediosNoLiberados,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                if (porTipoLiberacion.isNotEmpty) ...[
                  Text('Tipo de Liberación', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sections: _buildPieSectionsTipoLiberacion(porTipoLiberacion, porTipoLiberacion.values.fold(0, (a, b) => a + b)),
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: porTipoLiberacion.entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _tipoLiberacionColor(e.key),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${e.key}: ${fmtInt.format(e.value)}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                Text('Avance por Tipo de Propiedad', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Ver por:', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 10),
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDCDCDC)),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: DropdownButton<String>(
                          value: _segmentoActual ?? 'Proyecto',
                          isDense: true,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          items: [
                            const DropdownMenuItem(value: 'Proyecto', child: Text('Proyecto')),
                            ..._segmentos.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _segmentoActual = v == 'Proyecto' ? null : v;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTipoPropiedadCard(
                      titulo: 'Propiedad Privada',
                      predios: prediosPrivada,
                      fmtInt: fmtInt,
                    ),
                    const SizedBox(height: 16),
                    _buildTipoPropiedadCard(
                      titulo: 'Propiedad social/Dominio pleno',
                      predios: prediosSocialDominio,
                      fmtInt: fmtInt,
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                Text('Avance por Segmento/Tramo/Frente', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                if (porTramo.isEmpty)
                  const Text('Sin datos de tramos para este proyecto', style: TextStyle(color: AppColors.textSecondary))
                else ...[
                  SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (porTramo.values.reduce((a, b) => a > b ? a : b) * 1.2).toDouble(),
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (v, _) => Text(fmtInt.format(v.toInt()), style: const TextStyle(fontSize: 9)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                final keys = porTramo.keys.toList();
                                final idx = v.toInt();
                                if (idx < 0 || idx >= keys.length) return const SizedBox.shrink();
                                final label = keys[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    label.length > 8 ? label.substring(0, 8) : label,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: true),
                        barGroups: _buildSegmentBarGroups(porTramo, prediosFiltrados),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                Text('Avance Mensual', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (monthlyLiberados.isEmpty ? 10 : (monthlyLiberados.reduce((a, b) => a > b ? a : b) * 1.3)),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final now = DateTime.now();
                              final monthIndex = v.toInt();
                              final month = DateTime(now.year, now.month - (_sparkMonths - 1 - monthIndex));
                              final mesAbrev = _mesAbrev[month.month - 1];
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(mesAbrev, style: const TextStyle(fontSize: 9)),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: true),
                      barGroups: _buildMonthlyBarGroups(monthlyLiberados),
                    ),
                  ),
                ),
                const Text(
                  'Predios liberados por mes',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _segmentoActualExists(List<String> segmentos) {
    if (_segmentoActual == null) return true;
    return segmentos.contains(_segmentoActual);
  }

  static const _mesAbrev = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  String _resolveTipoLiberacion(Predio predio) {
    final gestion = _normalizeLiberacionToken(predio.tipoLiberacion);
    if (gestion.contains('AOP')) return 'AOP';
    if (gestion.contains('DOT')) return 'DOT';
    if (gestion.contains('COP')) return 'COP';

    final firmado = _normalizeLiberacionToken(predio.copFirmado);
    if (firmado.contains('AOP')) return 'AOP';
    if (firmado.contains('DOT')) return 'DOT';
    if (firmado.contains('COP')) return 'COP';

    if (predio.cop) {
      return (predio.copFirmado ?? '').trim().isNotEmpty ? 'COP' : 'Sin tipo';
    }
    return 'Sin liberación';
  }

  String _normalizeLiberacionToken(String? raw) {
    if (raw == null) return '';
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String _normalizeTipoLiberacionLabel(String tipo) {
    final t = _normalizeLiberacionToken(tipo);
    if (t.contains('AOP')) return 'AOP';
    if (t.contains('DOT')) return 'DOT';
    if (t.contains('COP')) return 'COP';
    if (tipo == 'Sin tipo / Sin liberación') return 'Sin tipo / Sin liberación';
    if (tipo == 'Sin tipo') return 'Sin tipo';
    if (tipo == 'Sin liberación') return 'Sin liberación';
    return tipo;
  }

  Color _tipoLiberacionColor(String tipo) {
    final normalized = _normalizeTipoLiberacionLabel(tipo);
    switch (normalized) {
      case 'COP': return AppColors.secondary;
      case 'DOT': return AppColors.info;
      case 'AOP': return AppColors.primary;
      case 'Sin tipo': return AppColors.warning;
      case 'Sin liberación': return AppColors.danger;
      case 'Sin tipo / Sin liberación': return AppColors.warning;
      default: return Colors.grey;
    }
  }

  List<BarChartGroupData> _buildSegmentBarGroups(Map<String, int> porTramo, List<Predio> todosPredios) {
    return porTramo.entries.toList().asMap().entries.map((e) {
      final tramo = e.value.key;
      final totalTramo = e.value.value;
      final liberadosTramo = todosPredios.where((p) => p.tramo == tramo && p.cop).length;
      
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: totalTramo.toDouble(),
            color: AppColors.primary,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            rodStackItems: [
              BarChartRodStackItem(0, liberadosTramo.toDouble(), AppColors.secondary),
              BarChartRodStackItem(liberadosTramo.toDouble(), totalTramo.toDouble(), AppColors.warning),
            ],
          ),
        ],
      );
    }).toList();
  }

  List<BarChartGroupData> _buildMonthlyBarGroups(List<double> monthlyData) {
    return monthlyData.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value,
            color: AppColors.secondary,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildAvanceDdvStatusBar({
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
                  if (pctLiber == 0 && pctNoLib == 0)
                    Expanded(child: Container(color: AppColors.border)),
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

  Widget _ddvLegend(String label, Color color, String value, double pct) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value (${(pct * 100).toStringAsFixed(1)}%)',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildKpiPanel({
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

  List<PieChartSectionData> _buildPieSectionsTipoLiberacion(Map<String, int> porTipo, int total) {
    return porTipo.entries.map((e) {
      final pct = total > 0 ? e.value / total * 100 : 0.0;
      return PieChartSectionData(
        color: _tipoLiberacionColor(e.key),
        value: e.value.toDouble(),
        title: '${pct.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
      );
    }).toList();
  }

  Widget _buildTipoPropiedadCard({
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
          // Cuadro de cuantificación
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
                      Text(
                        'Total de Predios: ',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
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
          // Gráficas de dona separadas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDonaSeparada(
                titulo: 'Identificación',
                completado: identificados,
                total: total,
                color: AppColors.info,
                icon: Icons.search,
              ),
              _buildDonaSeparada(
                titulo: 'Levantamiento',
                completado: levantados,
                total: total,
                color: AppColors.warning,
                icon: Icons.architecture,
              ),
              _buildDonaSeparada(
                titulo: 'Negociación',
                completado: negociados,
                total: total,
                color: AppColors.primary,
                icon: Icons.handshake,
              ),
              _buildDonaSeparada(
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

  Widget _buildDonaSeparada({
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
            Text(
              '0 / 0',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    
    final restante = total - completado;

    // Always show at least one visible segment when there are predios
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
}
