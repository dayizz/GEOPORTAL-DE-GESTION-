import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/predios/providers/predios_provider.dart';
import '../../../features/predios/models/predio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../estructura/models/proyecto_item.dart';
import '../../estructura/providers/proyectos_provider.dart';
import '../utils/balance_calculos.dart';
import 'widgets/balance_chart_widgets.dart';
import 'package:intl/intl.dart';

class BalanceScreen extends ConsumerStatefulWidget {
  const BalanceScreen({super.key});

  @override
  ConsumerState<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends ConsumerState<BalanceScreen> {
  /// Códigos de proyecto vigentes, dados de alta en Estructura (Firestore).
  List<String> get _proyectos => ref.read(proyectosCodigosProvider);

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
    // 'TQM' es un alias heredado (typo histórico); el código correcto es
    // 'TMQ' (Tren México-Querétaro).
    if (proyectoDirecto == 'TQM') return 'TMQ';
    if (proyectoDirecto != null && _proyectos.contains(proyectoDirecto)) {
      return proyectoDirecto;
    }

    final clave = predator.claveCatastral.trim().toUpperCase();
    final compact = clave.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.startsWith('TQI') || compact.startsWith('QI')) return 'TQI';
    if (compact.startsWith('TSNL') || compact.startsWith('SNL') || compact.startsWith('SL')) return 'TSNL';
    if (compact.startsWith('TAP') || compact.startsWith('AP')) return 'TAP';
    if (compact.startsWith('TMQ') || compact.startsWith('TQM') || compact.startsWith('QM')) {
      return 'TMQ';
    }

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
    if (contenido.contains('TQM')) return 'TMQ';

    return 'Sin proyecto';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(proyectosCodigosProvider);
    final prediosAsync = ref.watch(prediosMapaProvider);
    final fmtInt = NumberFormat('#,##0', 'es_MX');
    final canAllProjects = ref.watch(canAccessAllProjectsProvider);
    final proyectosAsignados = ref.watch(currentUserAssignedProjectsProvider);
    final sinProyectoAsignado = !canAllProjects && proyectosAsignados.isEmpty;
    final proyectosDisponibles = canAllProjects
        ? _proyectos
        : _proyectos.where(proyectosAsignados.contains).toList(growable: false);

    if (sinProyectoAsignado || proyectosDisponibles.isEmpty) {
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
          final porTramo = groupCountBy(prediosFiltrados, (predator) => predator.tramo);

          final prediosLiberados = prediosFiltrados.where((predator) => predator.cop).length;
          final prediosNoLiberados = (total - prediosLiberados).clamp(0, total);

          final kmEfectivosLiberados = prediosFiltrados
              .where((predator) => predator.cop)
              .fold<double>(0, (sum, predator) => sum + (predator.kmEfectivos ?? 0));

          // Agrupar por tipo de liberación usando primero el valor capturado
          // en Gestión ("Sin tipo"/"Sin liberación" ya consolidados).
          final porTipoLiberacion = porTipoLiberacionConsolidado(prediosFiltrados);

          // Distribución por "Rango de estatus" (Liberado, Negociación,
          // Posible DOT, Instrucción UVSR, Con ingreso, No liberado, L
          // nueva), ordenada según el catálogo vigente para que la dona y
          // su leyenda coincidan siempre en el mismo orden.
          final porRangoEstatus = ordenarRangoEstatus(
            groupCountBy(prediosFiltrados, (predator) => predator.rangoEstatus),
          );

          final prediosPrivada = prediosFiltrados.where((p) => p.tipoPropiedad.toUpperCase() == 'PRIVADA').toList();
          final prediosSocialDominio = prediosFiltrados
              .where((p) => p.tipoPropiedad.toUpperCase() == 'SOCIAL' || p.tipoPropiedad.toUpperCase() == 'DOMINIO PLENO')
              .toList();

          // "Avance Mensual"/"Avance Semanal": % acumulado de predios en
          // estatus "Liberado" al cierre de cada periodo (sobre el total
          // del proyecto/segmento filtrado), misma fuente única que el
          // resto de la app (`Predio.estatusSimplificado` sobre
          // `rangoEstatus`, no el flag `cop`).
          final pctLiberadoMensual = cumulativePctLiberado(
            prediosFiltrados,
            finesDePeriodo: List.generate(
              sparkMonths,
              (i) {
                final now = DateTime.now();
                final mes = DateTime(now.year, now.month - (sparkMonths - 1 - i));
                return DateTime(mes.year, mes.month + 1, 1);
              },
            ),
          );
          final pctLiberadoSemanal = cumulativePctLiberado(
            prediosFiltrados,
            finesDePeriodo: List.generate(
              sparkWeeks,
              (i) => weekStart(i).add(const Duration(days: 7)),
            ),
          );

          // Diagrama por Cadenamiento: usa el cadenamiento registrado en
          // Estructura > Proyectos para el proyecto activo. Se calcula sobre
          // TODOS los predios del proyecto (no respeta el filtro de
          // segmento de arriba), ya que el propio diagrama ya desglosa por
          // segmento/tramo/frente.
          final proyectosItems = ref.watch(proyectosProvider).valueOrNull ?? const <ProyectoItem>[];
          ProyectoItem? proyectoItemActivo;
          for (final p in proyectosItems) {
            if (p.nombre.trim().toUpperCase() == proyectoActivo) {
              proyectoItemActivo = p;
              break;
            }
          }
          final filasCadenamiento = buildFilasCadenamiento(proyectoItemActivo, proyectoPredios);

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
                      buildKpiPanel(
                        label: 'Total Predios',
                        value: fmtInt.format(total),
                        color: AppColors.primary,
                        icon: Icons.terrain_outlined,
                      ),
                      buildKpiPanel(
                        label: 'Km Efectivos Liberados',
                        value: fmtInt.format(kmEfectivosLiberados),
                        color: AppColors.secondary,
                        icon: Icons.straighten,
                      ),
                      buildKpiPanel(
                        label: 'Predios Liberados',
                        value: fmtInt.format(prediosLiberados),
                        color: AppColors.secondary,
                        icon: Icons.check_circle_outline,
                      ),
                      buildKpiPanel(
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
                            const Text('Avance DDV', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                              buildAvanceDdvStatusBar(
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
                if (porRangoEstatus.isNotEmpty || porTipoLiberacion.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final rangoBlock = porRangoEstatus.isEmpty
                          ? null
                          : buildEstatusChartBlock(
                              titulo: 'Rango de Estatus',
                              entries: porRangoEstatus,
                              total: total,
                              colorFn: AppColors.rangoEstatusColor,
                              borderColorFn: AppColors.rangoEstatusBorderColor,
                              fmtInt: fmtInt,
                            );
                      final tipoLiberacionBlock = porTipoLiberacion.isEmpty
                          ? null
                          : buildEstatusChartBlock(
                              titulo: 'Tipo de Liberación',
                              entries: porTipoLiberacion.entries.toList(),
                              total: porTipoLiberacion.values.fold(0, (a, b) => a + b),
                              colorFn: tipoLiberacionColor,
                              fmtInt: fmtInt,
                            );

                      final isWide = constraints.maxWidth >= 720;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (rangoBlock != null) Expanded(child: rangoBlock),
                            if (rangoBlock != null && tipoLiberacionBlock != null) const SizedBox(width: 24),
                            if (tipoLiberacionBlock != null) Expanded(child: tipoLiberacionBlock),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (rangoBlock != null) rangoBlock,
                          if (rangoBlock != null && tipoLiberacionBlock != null) const SizedBox(height: 20),
                          if (tipoLiberacionBlock != null) tipoLiberacionBlock,
                        ],
                      );
                    },
                  ),

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
                    buildTipoPropiedadCard(
                      titulo: 'Propiedad Privada',
                      predios: prediosPrivada,
                      fmtInt: fmtInt,
                    ),
                    const SizedBox(height: 16),
                    buildTipoPropiedadCard(
                      titulo: 'Propiedad social/Dominio pleno',
                      predios: prediosSocialDominio,
                      fmtInt: fmtInt,
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                Text('Avance por Segmento/Tramo/Frente', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                buildLiberadoLegend(),
                const SizedBox(height: 16),

                if (porTramo.isEmpty)
                  const Text('Sin datos de tramos para este proyecto', style: TextStyle(color: AppColors.textSecondary))
                else
                  buildStackedPctBars(
                    labels: porTramo.keys.toList(),
                    pctLiberadoPorBarra: pctLiberadoPorTramo(porTramo, prediosFiltrados),
                  ),

                const SizedBox(height: 32),
                Text('Diagrama por Cadenamiento', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Cada celda = 1 km. Color según % liberado dentro del km, calculado en vivo desde Gestión.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                if (filasCadenamiento.isEmpty)
                  const Text(
                    'Sin cadenamiento registrado para este proyecto (Configuración > Estructura > Proyectos).',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  for (final fila in filasCadenamiento) ...[
                    buildCadenamientoFilaCard(fila),
                    const SizedBox(height: 20),
                  ],

                const SizedBox(height: 12),
                Text('Avance Mensual', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                buildLiberadoLegend(),
                const SizedBox(height: 16),

                buildStackedPctBars(
                  labels: List.generate(sparkMonths, (i) {
                    final now = DateTime.now();
                    final mes = DateTime(now.year, now.month - (sparkMonths - 1 - i));
                    return mesAbrev[mes.month - 1];
                  }),
                  pctLiberadoPorBarra: pctLiberadoMensual,
                ),
                const Text(
                  '% acumulado de predios liberados al cierre de cada mes (sobre el total del proyecto/segmento)',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),

                const SizedBox(height: 32),
                Text('Avance Semanal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                buildLiberadoLegend(),
                const SizedBox(height: 16),

                buildStackedPctBars(
                  labels: List.generate(sparkWeeks, (i) => DateFormat('d/MM').format(weekStart(i))),
                  pctLiberadoPorBarra: pctLiberadoSemanal,
                ),
                const Text(
                  '% acumulado de predios liberados al cierre de cada semana (últimas 8 semanas, sobre el total del proyecto/segmento)',
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
}
