import '../utils/resumen_tramos.dart';
import 'widgets/resumen_tramos_widget.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/predios/providers/predios_provider.dart';
import '../../../features/predios/models/predio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/import_normalization.dart' as norm;
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
  GrupoInfraestructuraBalance _grupoActual =
      GrupoInfraestructuraBalance.predios;
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
    if (compact.startsWith('TSNL') ||
        compact.startsWith('SNL') ||
        compact.startsWith('SL'))
      return 'TSNL';
    if (compact.startsWith('TAP') || compact.startsWith('AP')) return 'TAP';
    if (compact.startsWith('TMQ') ||
        compact.startsWith('TQM') ||
        compact.startsWith('QM')) {
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
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.danger,
              ),
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

          final proyectosItems =
              ref.watch(proyectosProvider).valueOrNull ??
              const <ProyectoItem>[];
          ProyectoItem? proyectoItemActivo;
          for (final p in proyectosItems) {
            if (p.nombre.trim().toUpperCase() == proyectoActivo) {
              proyectoItemActivo = p;
              break;
            }
          }

          // Extraer segmentos únicos del proyecto
          final segmentos = proyectoPredios
              .where((p) => p.tramo.isNotEmpty)
              .map((p) => claveTramoBalance(p.tramo, proyectoItemActivo))
              .where((codigo) => codigo != 'S15' && codigo != '15' && codigo != 'S15A')
              .toSet()
              .toList();
          segmentos.sort();

          // Actualizar la lista de segmentos si cambió el proyecto
          {
            _segmentos = segmentos;
            if (_segmentoActual != null &&
                !segmentos.contains(_segmentoActual)) {
              _segmentoActual = null;
            }
          }

          // Filtrar por segmento si hay uno seleccionado
          final registrosFiltrados = _segmentoActual != null
              ? proyectoPredios
                    .where((p) => claveTramoBalance(p.tramo, proyectoItemActivo) == _segmentoActual)
                    .toList()
              : proyectoPredios;

          final grupos = agruparInfraestructuraBalance(registrosFiltrados);
          final prediosFiltrados = grupos[_grupoActual]!;
          final tituloGrupo = switch (_grupoActual) {
            GrupoInfraestructuraBalance.estacionesEdificios =>
              'Estaciones y Edificios Auxiliares',
            GrupoInfraestructuraBalance.cruces => 'Cruces/Transversales',
            _ => 'Predios',
          };
          final enInvestigacion =
              grupos[GrupoInfraestructuraBalance.nulos]!.length +
              grupos[GrupoInfraestructuraBalance.sinAfectacion]!.length +
              grupos[GrupoInfraestructuraBalance.otros]!.length;

          final total = prediosFiltrados.length;


          final prediosLiberados = prediosFiltrados
              .where(predioEstaLiberado)
              .length;
          final prediosNegociacion = prediosFiltrados.where((p) =>
              norm.stripAccents(p.rangoEstatus).trim().toUpperCase() ==
              'NEGOCIACION').length;
          final prediosNoLiberados = (total - prediosLiberados).clamp(0, total);

          final usaM2 = _grupoActual == GrupoInfraestructuraBalance.estacionesEdificios;
          final unidad = usaM2 ? 'm²' : 'km';
          double medidaPredio(Predio p) => medidaPredioBalance(p, usaM2: usaM2);
          final medidaLiberada = prediosFiltrados
              .where(predioEstaLiberado)
              .fold<double>(
                0,
                (sum, predator) => sum + medidaPredio(predator),
              );

          // Agrupar por tipo de liberación usando primero el valor capturado
          // en Gestión ("Sin tipo"/"Sin liberación" ya consolidados).
          final porTipoLiberacion = tiposDeRegistrosLiberados(
            prediosFiltrados,
          );

          // Distribución por "Estatus" (Liberado, Negociación,
          // Posible DOT, Instrucción UVSR, Con ingreso, No liberado, L
          // nueva), ordenada según el catálogo vigente para que la dona y
          // su leyenda coincidan siempre en el mismo orden.
          final porRangoEstatus = ordenarRangoEstatus(
            groupCountBy(prediosFiltrados, (predator) => predator.rangoEstatus),
          );

          final prediosPrivada = prediosFiltrados
              .where((p) => p.tipoPropiedad.trim().toUpperCase() == 'PRIVADA')
              .toList();
          final prediosSocialDominio = prediosFiltrados
              .where(
                (p) => const {
                  'SOCIAL',
                  'DOMINIO PLENO',
                  'FEDERAL',
                  'GUBERNAMENTAL',
                  'ESTATAL',
                  'MUNICIPAL',
                }.contains(p.tipoPropiedad.trim().toUpperCase()),
              )
              .toList();
          final propiedadDesconocida = prediosFiltrados.where((p) => const {
            'DESCONOCIDO', '', 'NULO', 'NULL',
          }.contains(p.tipoPropiedad.trim().toUpperCase())).length;

          // Base: suma de los cadenamientos registrados, sin exigir longitud
          // a los códigos que solo existen en los datos de Gestión.
            final medidaTotal = usaM2
              ? prediosFiltrados.fold<double>(0, (sum, p) => sum + medidaPredio(p))
              : resumenTramosBalance(proyectoItemActivo, [])
              .fold<double>(0, (sum, fila) => sum + (fila.longitud ?? 0));
          final ahora = DateTime.now();
          final meses = List.generate(6, (i) => DateTime(ahora.year, ahora.month - 5 + i));
          final semanas = List.generate(12, (i) => weekStart(i, totalSemanas: 12));
          final pctLiberadoMensual = pctMedidaLiberadaPorPeriodo(
            prediosFiltrados, medidaTotal: medidaTotal, medida: medidaPredio, inicios: meses,
            fines: meses.map((m) => DateTime(m.year, m.month + 1)).toList(),
          );
          final pctLiberadoSemanal = pctMedidaLiberadaPorPeriodo(
            prediosFiltrados, medidaTotal: medidaTotal, medida: medidaPredio, inicios: semanas,
            fines: semanas.map((s) => s.add(const Duration(days: 7))).toList(),
          );

          // El cadenamiento utiliza el mismo grupo y segmento que los indicadores.
          final filasCadenamiento = buildFilasCadenamiento(
            proyectoItemActivo,
            prediosFiltrados,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Proyecto:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF555555),
                          ),
                        ),
                        const SizedBox(width: 10),
                        DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFDCDCDC),
                              ),
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                            ),
                            child: DropdownButton<String>(
                              value: proyectoActivo,
                              isDense: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: Color(0xFF9A9A9A),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              items: proyectosDisponibles
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p),
                                    ),
                                  )
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

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Ver como:', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 10),
                        DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFDCDCDC),
                              ),
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                            ),
                            child: DropdownButton<String>(
                              value:
                                  _grupoActual ==
                                      GrupoInfraestructuraBalance
                                          .estacionesEdificios
                                  ? 'grupo:estaciones'
                                  : _grupoActual ==
                                        GrupoInfraestructuraBalance.cruces
                                  ? 'grupo:cruces'
                                  : _segmentoActual == null
                                  ? 'Proyecto'
                                  : 'segmento:$_segmentoActual',
                              isDense: true,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'Proyecto',
                                  child: Text('Proyecto'),
                                ),
                                const DropdownMenuItem(
                                  value: 'grupo:estaciones',
                                  child: Text(
                                    'Estaciones y Edificios Auxiliares',
                                  ),
                                ),
                                const DropdownMenuItem(
                                  value: 'grupo:cruces',
                                  child: Text('Cruces/Transversales'),
                                ),
                                ..._segmentos.map(
                                  (s) => DropdownMenuItem(
                                    value: 'segmento:$s',
                                    child: Text(s),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _grupoActual = switch (v) {
                                    'grupo:estaciones' =>
                                      GrupoInfraestructuraBalance
                                          .estacionesEdificios,
                                    'grupo:cruces' =>
                                      GrupoInfraestructuraBalance.cruces,
                                    _ => GrupoInfraestructuraBalance.predios,
                                  };
                                  _segmentoActual =
                                      v != null && v.startsWith('segmento:')
                                      ? v.substring('segmento:'.length)
                                      : null;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Text(
                  'Avance general',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(tituloGrupo),
                const SizedBox(height: 12),
                _panelesConteo([
                  buildKpiPanel(
                    label: 'Total de registros clasificados',
                    value: fmtInt.format(total),
                    color: AppColors.primary,
                    icon: Icons.summarize_outlined,
                  ),
                  buildKpiPanel(
                    label: 'Total no liberados',
                    value: fmtInt.format(prediosNoLiberados),
                    color: AppColors.danger,
                    icon: Icons.pending_outlined,
                  ),
                  buildKpiPanel(
                    label: 'Total liberados',
                    value: fmtInt.format(prediosLiberados),
                    color: AppColors.secondary,
                    icon: Icons.check_circle_outline,
                  ),
                  Tooltip(
                    message:
                        'Nulos, sin afectación y sin clasificación del proyecto o segmento seleccionado.',
                    child: buildKpiPanel(
                      label: 'Total de registros en investigación',
                      value: fmtInt.format(enInvestigacion),
                      color: Colors.grey,
                      icon: Icons.help_outline,
                    ),
                  ),
                  buildKpiPanel(
                    label: usaM2 ? 'M² liberados' : 'Km efectivos liberados',
                    value:
                      '${NumberFormat('#,##0.###', 'es_MX').format(medidaLiberada)} $unidad',
                    color: AppColors.secondary,
                    icon: Icons.straighten,
                  ),
                ]),
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
                            const Text(
                              'Avance de liberación',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (total == 0)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'No hay registros para la selección actual',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              buildAvanceDdvStatusBar(
                                context: context,
                                total: total,
                                liberado: prediosLiberados,
                                noLiberado: prediosNoLiberados - prediosNegociacion,
                                negociacion: prediosNegociacion,
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
                              titulo: 'Estatus',
                              entries: porRangoEstatus,
                              total: total,
                              colorFn: AppColors.rangoEstatusColor,
                              borderColorFn: AppColors.rangoEstatusBorderColor,
                              fmtInt: fmtInt,
                            );
                      final tipoLiberacionBlock = porTipoLiberacion.isEmpty
                          ? null
                          : buildEstatusChartBlock(
                              titulo: 'Tipo de liberación (liberados)',
                              entries: porTipoLiberacion.entries.toList(),
                              total: porTipoLiberacion.values.fold(
                                0,
                                (a, b) => a + b,
                              ),
                              colorFn: tipoLiberacionColor,
                              fmtInt: fmtInt,
                            );

                      final isWide = constraints.maxWidth >= 720;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (rangoBlock != null) Expanded(child: rangoBlock),
                            if (rangoBlock != null &&
                                tipoLiberacionBlock != null)
                              const SizedBox(width: 24),
                            if (tipoLiberacionBlock != null)
                              Expanded(child: tipoLiberacionBlock),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (rangoBlock != null) rangoBlock,
                          if (rangoBlock != null && tipoLiberacionBlock != null)
                            const SizedBox(height: 20),
                          if (tipoLiberacionBlock != null) tipoLiberacionBlock,
                        ],
                      );
                    },
                  ),

                const SizedBox(height: 32),
                Text(
                  'Avance por Tipo de Propiedad',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 20),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildTipoPropiedadCard(
                      titulo: 'PRIVADA',
                      predios: prediosPrivada,
                      fmtInt: fmtInt,
                    ),
                    const SizedBox(height: 16),
                    buildTipoPropiedadCard(
                      titulo: 'SOCIAL/DOMINIO PLENO',
                      predios: prediosSocialDominio,
                      fmtInt: fmtInt,
                    ),
                    if (propiedadDesconocida > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Registros con tipo de propiedad desconocido o nulo: ${fmtInt.format(propiedadDesconocida)}. No incluidos en los grupos anteriores.',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 32),
                Text(
                  'Avance por Segmento/Tramo/Frente',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ResumenTramosWidget(
                  usaM2: usaM2,
                  filas: resumenTramosBalance(proyectoItemActivo, prediosFiltrados,
                    segmento: _segmentoActual),
                ),

                const SizedBox(height: 32),
                if (!usaM2) ...[
                Text(
                  'Diagrama por Cadenamiento',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cada celda = 1 km. Color según % liberado dentro del km, calculado en vivo desde Gestión.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                if (filasCadenamiento.isEmpty)
                  Text(
                    'Sin cadenamiento registrado para este proyecto (Configuración > Estructura > Proyectos).',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  for (final fila in filasCadenamiento) ...[
                    buildCadenamientoFilaCard(fila),
                    const SizedBox(height: 20),
                  ],

                const SizedBox(height: 12),
                ],
                Text('Avance por ${usaM2 ? 'm²' : 'km efectivos'} liberados · ${usaM2 ? 'Superficie' : 'Longitud'} total: ${NumberFormat('#,##0.###', 'es_MX').format(medidaTotal)} $unidad'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    buildLegendItem('$unidad liberados en el periodo', AppColors.secondary),
                    buildLegendItem(usaM2 ? 'Resto de la superficie total' : 'Resto de la longitud total', AppColors.danger),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: math.max(1100.0, constraints.maxWidth),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Avance mensual · Últimos 6 meses', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        buildStackedPctBars(
                          labels: meses.map((m) => DateFormat('MM/yyyy').format(m)).toList(),
                          pctLiberadoPorBarra: pctLiberadoMensual,
                        ),
                      ])),
                      const SizedBox(width: 24),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Avance semanal · Últimas 12 semanas', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        buildStackedPctBars(
                          labels: semanas.map((s) => DateFormat('d/MM').format(s)).toList(),
                          pctLiberadoPorBarra: pctLiberadoSemanal,
                        ),
                      ])),
                    ]),
                  ),
                )),
                const SizedBox(height: 8),
                Text('$unidad liberados en cada periodo / ${usaM2 ? 'superficie' : 'longitud'} total × 100. Sin registros de liberación en el periodo: 0%.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _panelesConteo(List<Widget> paneles) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = math.max(constraints.maxWidth, 1000.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: ancho,
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < paneles.length; i++) ...[
                  Expanded(child: paneles[i]),
                  if (i < paneles.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
