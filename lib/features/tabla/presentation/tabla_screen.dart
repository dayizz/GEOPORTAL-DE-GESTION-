import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:async';
import 'dart:math' as math;
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/browser_download.dart';
import '../../carga/utils/file_download_io.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../../predios/data/predios_repository.dart';
import '../../predios/models/predio.dart';
import '../../predios/providers/local_predios_provider.dart';
import '../../predios/providers/predios_provider.dart';
import '../../propietarios/providers/local_propietarios_provider.dart';
import '../../propietarios/providers/propietarios_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../estructura/providers/proyectos_provider.dart';
import '../../../core/utils/import_normalization.dart' as norm;

class TablaScreen extends ConsumerStatefulWidget {
  const TablaScreen({super.key});

  @override
  ConsumerState<TablaScreen> createState() => _TablaScreenState();
}


class _TablaScreenState extends ConsumerState<TablaScreen> {
  /// Códigos de proyecto vigentes, dados de alta en Estructura (Firestore).
  List<String> get _proyectos => ref.read(proyectosCodigosProvider);

  final _searchCtrl = TextEditingController();
  final _verticalScroll = ScrollController();
  final _horizontalScroll = ScrollController();
  final Map<String, Predio> _prediosOptimistas = {};
  List<Predio> _ultimosPredios = const [];

  String _proyectoActual = 'TQI';
  String _busqueda = '';
  Set<String> _filtroTramo = {};
  Set<String> _filtroTipo = {};
  Set<String> _filtroTipoLiberacion = {};
  Set<String> _filtroEstatus = {}; // 'Liberado' | 'No liberado'
  Set<String> _filtroRangoEstatus = {};
  Set<String> _filtroEstructura = {};

  final _nf = NumberFormat('#,##0.00');
  final _nf4 = NumberFormat('0.0000');
  bool _normalizacionInicialAplicada = false;
  bool _dismissLiberadosAlert = false;
  bool _autocompletandoLiberados = false;

  // Paginación
  static const int _rowsPerPage = 50;
  int _currentPage = 0;

  void _goToPage(int page, int totalRows) {
    final maxPage = (totalRows / _rowsPerPage).ceil() - 1;
    setState(() {
      _currentPage = page.clamp(0, maxPage);
    });
    _verticalScroll.jumpTo(0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _normalizarDatosLocalesExistentes();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  void _normalizarDatosLocalesExistentes() {
    if (_normalizacionInicialAplicada || !mounted) return;
    _normalizacionInicialAplicada = true;

    final prediosActualizados =
        ref.read(localPrediosProvider.notifier).normalizeExistingData();
    final prediosDeduplicados =
        ref.read(localPrediosProvider.notifier).deduplicateExistingData();
    final propietariosActualizados =
        ref.read(localPropietariosProvider.notifier).normalizeExistingData();

    final totalActualizados =
        prediosActualizados + propietariosActualizados + prediosDeduplicados;
    if (totalActualizados > 0) {
      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
      ref.invalidate(propietariosListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Normalizacion aplicada: $prediosActualizados predio(s) y '
            '$propietariosActualizados propietario(s). '
            '${prediosDeduplicados > 0 ? "Duplicados eliminados: $prediosDeduplicados." : ""}',
          ),
        ),
      );
    }
  }

  // Memoización de filtros
  List<Predio>? _lastAll;
  String? _lastProyecto;
  Set<String> _lastTramo = {};
  Set<String> _lastTipo = {};
  Set<String> _lastTipoLiberacion = {};
  Set<String> _lastEstatus = {};
  Set<String> _lastRangoEstatus = {};
  Set<String> _lastEstructura = {};
  String? _lastBusqueda;
  List<Predio>? _lastFiltered;

  List<Predio> _applyFilters(List<Predio> all) {
    final shouldRecompute = _lastAll != all ||
        _lastProyecto != _proyectoActual ||
        !setEquals(_lastTramo, _filtroTramo) ||
        !setEquals(_lastTipo, _filtroTipo) ||
        !setEquals(_lastTipoLiberacion, _filtroTipoLiberacion) ||
        !setEquals(_lastEstatus, _filtroEstatus) ||
        !setEquals(_lastRangoEstatus, _filtroRangoEstatus) ||
        !setEquals(_lastEstructura, _filtroEstructura) ||
        _lastBusqueda != _busqueda;
    if (!shouldRecompute && _lastFiltered != null) {
      return _lastFiltered!;
    }
    final filtered = all.where((p) {
      if (_predioProyecto(p) != _proyectoActual) return false;
      if (_filtroTramo.isNotEmpty && !_filtroTramo.contains(p.tramo)) return false;
      if (_filtroTipo.isNotEmpty && !_filtroTipo.contains(p.tipoPropiedad)) return false;
      if (_filtroEstatus.isNotEmpty) {
        final estatus = Predio.estatusSimplificado(p.rangoEstatus);
        if (!_filtroEstatus.contains(estatus)) return false;
      }
      if (_filtroRangoEstatus.isNotEmpty && !_filtroRangoEstatus.contains(p.rangoEstatus)) return false;
      if (_filtroTipoLiberacion.isNotEmpty) {
        final tipoLiberacion = _normalizarTipoLiberacion(p.tipoLiberacion);
        if (!_filtroTipoLiberacion.contains(tipoLiberacion)) return false;
      }
      if (_filtroEstructura.isNotEmpty &&
          !_filtroEstructura.contains((p.estructura ?? '').trim().toUpperCase())) {
        return false;
      }
      if (_busqueda.isNotEmpty) {
        final q = _busqueda.toLowerCase();
        return p.claveCatastral.toLowerCase().contains(q) ||
            (p.propietarioNombre?.toLowerCase().contains(q) ?? false) ||
            (p.ejido?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
    _lastAll = all;
    _lastProyecto = _proyectoActual;
    _lastTramo = Set.of(_filtroTramo);
    _lastTipo = Set.of(_filtroTipo);
    _lastTipoLiberacion = Set.of(_filtroTipoLiberacion);
    _lastEstatus = Set.of(_filtroEstatus);
    _lastRangoEstatus = Set.of(_filtroRangoEstatus);
    _lastEstructura = Set.of(_filtroEstructura);
    _lastBusqueda = _busqueda;
    _lastFiltered = filtered;
    return filtered;
  }

  bool get _tieneFiltrosActivos =>
      _filtroTramo.isNotEmpty ||
      _filtroTipo.isNotEmpty ||
      _filtroTipoLiberacion.isNotEmpty ||
      _filtroEstatus.isNotEmpty ||
      _filtroRangoEstatus.isNotEmpty ||
      _filtroEstructura.isNotEmpty;

  int get _totalFiltrosActivos =>
      _filtroTramo.length +
      _filtroTipo.length +
      _filtroTipoLiberacion.length +
      _filtroEstatus.length +
      _filtroRangoEstatus.length +
      _filtroEstructura.length;

  String _normalizarTipoLiberacion(String? value) {
    final text = (value ?? '').trim().toUpperCase();
    if (text.isEmpty || text == '-') return 'SIN TIPO';
    return text;
  }

  String _predioProyecto(Predio predio) {
    final proyectoDirecto = predio.proyecto?.trim().toUpperCase();
    // 'TQM' es un alias heredado (typo histórico); el código correcto es
    // 'TMQ' (Tren México-Querétaro).
    if (proyectoDirecto == 'TQM') return 'TMQ';
    if (proyectoDirecto != null && _proyectos.contains(proyectoDirecto)) {
      return proyectoDirecto;
    }

    final clave = predio.claveCatastral.trim().toUpperCase();
    final compact = clave.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.startsWith('TQI') || compact.startsWith('QI')) return 'TQI';
    if (compact.startsWith('TSNL') || compact.startsWith('SNL') || compact.startsWith('SL')) return 'TSNL';
    if (compact.startsWith('TAP') || compact.startsWith('AP')) return 'TAP';
    if (compact.startsWith('TMQ') || compact.startsWith('TQM') || compact.startsWith('QM')) {
      return 'TMQ';
    }

    final contenido = [
      predio.claveCatastral,
      predio.ejido ?? '',
      predio.poligonoDwg ?? '',
      predio.oficio ?? '',
      predio.pdfUrl ?? '',
      predio.copFirmado ?? '',
    ].join(' ').toUpperCase();

    for (final proyecto in _proyectos) {
      if (contenido.contains(proyecto)) return proyecto;
    }
    if (contenido.contains('TQM')) return 'TMQ';

    return 'Sin proyecto';
  }

  int _conteoProyecto(List<Predio> predios, String proyecto) {
    return predios.where((predio) => _predioProyecto(predio) == proyecto).length;
  }

  List<String> _opcionesTramoProyecto(List<Predio> predios) {
    final tramos = predios
        .where((predio) => _predioProyecto(predio) == _proyectoActual)
        .map((predio) => predio.tramo.trim().toUpperCase())
        .where((tramo) => tramo.isNotEmpty)
        .toSet()
        .toList();
    tramos.sort(_compararCodigoAlfanumerico);
    return tramos;
  }

  List<String> _opcionesTipoProyecto(List<Predio> predios) {
    final tipos = predios
        .where((predio) => _predioProyecto(predio) == _proyectoActual)
        .map((predio) => predio.tipoPropiedad.trim().toUpperCase())
        .where((tipo) => tipo.isNotEmpty)
        .toSet()
        .toList();
    tipos.sort((a, b) => a.compareTo(b));
    return tipos;
  }

  List<String> _opcionesEstructuraProyecto(List<Predio> predios) {
    final estructuras = predios
        .where((predio) => _predioProyecto(predio) == _proyectoActual)
        .map((predio) => (predio.estructura ?? '').trim().toUpperCase())
        .where((estructura) => estructura.isNotEmpty)
        .toSet()
        .toList();
    estructuras.sort((a, b) => a.compareTo(b));
    return estructuras;
  }

  List<String> _opcionesTipoLiberacionProyecto(List<Predio> predios) {
    final tiposLiberacion = predios
        .where((predio) => _predioProyecto(predio) == _proyectoActual)
        .map((predio) => _normalizarTipoLiberacion(predio.tipoLiberacion))
        .toSet()
        .toList();
    tiposLiberacion.sort((a, b) {
      if (a == 'SIN TIPO') return 1;
      if (b == 'SIN TIPO') return -1;
      return a.compareTo(b);
    });
    return tiposLiberacion;
  }

  int _compararCodigoAlfanumerico(String a, String b) {
    final exp = RegExp(r'^([A-Z]+)(\d+)$');
    final ma = exp.firstMatch(a);
    final mb = exp.firstMatch(b);
    if (ma != null && mb != null) {
      final prefA = ma.group(1)!;
      final prefB = mb.group(1)!;
      final prefComp = prefA.compareTo(prefB);
      if (prefComp != 0) return prefComp;
      final na = int.tryParse(ma.group(2)!) ?? 0;
      final nb = int.tryParse(mb.group(2)!) ?? 0;
      return na.compareTo(nb);
    }
    return a.compareTo(b);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(proyectosCodigosProvider);
    final prediosAsync = ref.watch(prediosListProvider);
    final canAllProjects = ref.watch(canAccessAllProjectsProvider);
    final proyectosAsignados = ref.watch(currentUserAssignedProjectsProvider);
    final sinProyectoAsignado = !canAllProjects && proyectosAsignados.isEmpty;
    final proyectosDisponibles = canAllProjects
        ? _proyectos
        : _proyectos.where(proyectosAsignados.contains).toList(growable: false);
    if (!sinProyectoAsignado &&
        proyectosDisponibles.isNotEmpty &&
        !proyectosDisponibles.contains(_proyectoActual)) {
      final fallback = proyectosDisponibles.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _proyectoActual = fallback);
      });
    }
    Widget content;
    if (sinProyectoAsignado) {
      content = const Center(
        child: Text(
          'Sin proyecto asignado',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      );
    } else if (prediosAsync.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (prediosAsync.hasError) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('Error al cargar los datos', style: TextStyle(color: AppColors.danger)),
            const SizedBox(height: 8),
            Text(prediosAsync.error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(prediosListProvider),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else {
      // Si no hay datos, mostrar mensaje amigable y evitar errores
      final remoteData = prediosAsync.asData?.value;
      final prediosList = remoteData ?? _ultimosPredios;
      if (prediosList.isEmpty) {
        content = Column(
          children: [
            _buildTopBar(0, const [], proyectosDisponibles, 0),
            const Divider(height: 1),
            const Expanded(
              child: Center(
                child: Text(
                  'No hay predios registrados aún. Importa un archivo o agrega datos para comenzar.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      } else {
        _ultimosPredios = prediosList;
        final allPredios = prediosList
            .map((predio) => _prediosOptimistas[predio.id] ?? predio)
            .toList(growable: false);
        final filtered = _applyFilters(allPredios);
        final totalPages = filtered.isEmpty ? 1 : (filtered.length / _rowsPerPage).ceil();
        final maxPage = totalPages - 1;
        final safePage = _currentPage > maxPage ? maxPage : _currentPage;
        if (safePage != _currentPage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _currentPage = safePage);
          });
        }
        final startRow = safePage * _rowsPerPage;
        final pageRows = filtered.skip(startRow).take(_rowsPerPage).toList();
        final rowsToRender = (pageRows.isEmpty && filtered.isNotEmpty)
            ? filtered.take(_rowsPerPage).toList(growable: false)
            : pageRows;
        if (pageRows.isEmpty && filtered.isNotEmpty && _currentPage != 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _currentPage = 0);
          });
        }

        // Auto-seleccionar el proyecto solicitado por la pantalla de carga (post-importación)
        final proyectoSolicitado = ref.watch(gestionProyectoProvider);
        if (proyectoSolicitado != null && _proyectos.contains(proyectoSolicitado)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _proyectoActual = proyectoSolicitado;
              _busqueda = '';
              _searchCtrl.clear();
              _filtroTramo = {};
              _filtroTipo = {};
              _filtroTipoLiberacion = {};
              _filtroEstatus = {};
              _filtroRangoEstatus = {};
              _filtroEstructura = {};
              _currentPage = 0;
            });
            ref.read(gestionProyectoProvider.notifier).state = null;
          });
        }

        final liberadosIncompletos = filtered
            .where((p) =>
                Predio.estatusSimplificado(p.rangoEstatus) == 'Liberado' &&
                (!p.identificacion || !p.levantamiento || !p.negociacion))
            .toList(growable: false);
        if (liberadosIncompletos.isEmpty) {
          _dismissLiberadosAlert = false;
        }

        final camposIncompletos = filtered.where(_tieneCamposIncompletos).length;

        // Numeracion estable por proyecto: se calcula sobre TODOS los
        // predios del proyecto actual (sin busqueda/filtros secundarios ni
        // paginacion), para que el ID de un registro no cambie segun que
        // filtro este activo en el momento.
        final proyectoOrdenado = allPredios
            .where((p) => _predioProyecto(p) == _proyectoActual)
            .toList(growable: false);
        final idPorPredio = <String, int>{
          for (var i = 0; i < proyectoOrdenado.length; i++) proyectoOrdenado[i].id: i + 1,
        };

        content = Column(
          children: [
            _buildTopBar(filtered.length, allPredios, proyectosDisponibles, camposIncompletos),
            const Divider(height: 1),
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page),
                      onPressed: _currentPage > 0
                          ? () => _goToPage(0, filtered.length)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 0
                          ? () => _goToPage(_currentPage - 1, filtered.length)
                          : null,
                    ),
                    Text('Página ${_currentPage + 1} de $totalPages'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < totalPages - 1
                          ? () => _goToPage(_currentPage + 1, filtered.length)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      onPressed: _currentPage < totalPages - 1
                          ? () => _goToPage(totalPages - 1, filtered.length)
                          : null,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildTable(rowsToRender, idPorPredio),
                  ),
                  if (liberadosIncompletos.isNotEmpty && !_dismissLiberadosAlert)
                    Positioned(
                      right: 12,
                      bottom: 72,
                      child: _buildLiberadosAlert(liberadosIncompletos),
                    ),
                ],
              ),
            ),
          ],
        );
      }
    }

    return AppScaffold(
      currentIndex: 3,
      title: 'Gestion',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Registrar nuevo predio',
          onPressed: () => context.push('/predios/nuevo?proyecto=$_proyectoActual'),
        ),
        IconButton(
          icon: const Icon(Icons.download),
          tooltip: 'Exportar a Excel',
          onPressed: () {
            final prediosAsync = ref.read(prediosListProvider);
            final prediosList = prediosAsync.asData?.value ?? [];
            final allPredios = prediosList.map((p) => _prediosOptimistas[p.id] ?? p).toList();
            final filtered = _applyFilters(allPredios);
            final proyectoOrdenado = allPredios
                .where((p) => _predioProyecto(p) == _proyectoActual)
                .toList(growable: false);
            final idPorPredio = <String, int>{
              for (var i = 0; i < proyectoOrdenado.length; i++) proyectoOrdenado[i].id: i + 1,
            };
            _exportToExcel(filtered, idPorPredio);
          },
        ),
      ],
      child: content,
    );
  }

  Future<void> _exportToExcel(List<Predio> predios, Map<String, int> idPorPredio) async {
    if (predios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Gestion $_proyectoActual'];
      final fecha = DateFormat('ddMMyyyy').format(DateTime.now());
      final fileName = 'Gestion_${_proyectoActual}_$fecha.xlsx';
      
      // Headers
      final headers = [
        'ID', 'CLAVE', 'PROYECTO', 'T/F/S', 'TIPO', 'ESTRUCTURA', 'ESTADO', 'MUNICIPIO',
        'EJIDO', 'PROPIETARIO', 'KM INICIO', 'KM FIN', 'KM EFECTIVOS',
        'SUPERFICIE M2', 'COP', 'FECHA DE LIBERACION', 'COP/DOT PDF', 'DWG', 'PLANO PDF', 'BDT',
        'RANGO ESTATUS', 'ESTATUS',
        'IDENTIFICACION', 'LEVANTAMIENTO', 'NEGOCIACION', 'OBSERVACIONES', 'FECHA LIMITE DE PAGO'
      ];
      
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
      }
      
      // Data rows
      for (var row = 0; row < predios.length; row++) {
        final p = predios[row];
        final rowData = [
          idPorPredio[p.id]?.toString() ?? '',
          p.claveCatastral,
          _predioProyecto(p),
          p.tramo,
          p.tipoPropiedad,
          p.estructura ?? '',
          p.estado ?? '',
          p.municipio ?? '',
          p.ejido ?? '',
          p.propietarioNombre ?? '',
          p.kmInicio != null ? norm.formatKmPk(p.kmInicio!) : '',
          p.kmFin != null ? norm.formatKmPk(p.kmFin!) : '',
          p.kmEfectivos?.toString() ?? '',
          p.superficie?.toString() ?? '',
          p.cop ? 'SI' : 'NO',
          p.copFecha != null ? '${p.copFecha!.day}/${p.copFecha!.month}/${p.copFecha!.year}' : '',
          _pdfUrlFor(p) ?? '',
          p.poligonoDwg ?? '',
          p.planoPdf ?? '',
          p.bdt ?? '',
          p.rangoEstatus,
          Predio.estatusSimplificado(p.rangoEstatus),
          p.identificacion ? 'SI' : 'NO',
          p.levantamiento ? 'SI' : 'NO',
          p.negociacion ? 'SI' : 'NO',
          p.situacionSocial ?? '',
          p.fechaLimitePago != null
              ? '${p.fechaLimitePago!.day}/${p.fechaLimitePago!.month}/${p.fechaLimitePago!.year}'
              : '',
        ];
        
        for (var col = 0; col < rowData.length; col++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1)).value = TextCellValue(rowData[col].toString());
        }
      }
      
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Error al codificar Excel');
      }
      
      // Para web, usar una solución diferente
      if (kIsWeb) {
        await downloadBytesForBrowser(
          Uint8List.fromList(bytes),
          fileName: fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        // En desktop, share_plus abre un popover de macOS que requiere un
        // rect de anclaje (sharePositionOrigin); sin él no se muestra nada
        // y el archivo se queda solo en el directorio temporal, dando la
        // impresión de que la descarga no hizo nada. Se guarda directo en
        // Descargas, igual que el resto de las exportaciones de la app.
        await downloadBytes(
          Uint8List.fromList(bytes),
          fileName: fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportados ${predios.length} registros')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Widget _buildTopBar(int visible, List<Predio> allPredios, List<String> proyectosDisponibles, int camposIncompletos) {
    if (proyectosDisponibles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No hay proyectos dados de alta en Estructura.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final proyectoDropdownValue = proyectosDisponibles.contains(_proyectoActual)
        ? _proyectoActual
        : proyectosDisponibles.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
              const Icon(Icons.folder_outlined, size: 16, color: AppColors.textSecondary),
              const Text(
                'Proyecto:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: proyectoDropdownValue,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      items: proyectosDisponibles.map((proyecto) {
                        final count = _conteoProyecto(allPredios, proyecto);
                        return DropdownMenuItem<String>(
                          value: proyecto,
                          child: Row(
                            children: [
                              Text(
                                proyecto,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _proyectoActual = v);
                      },
                    ),
                  ),
                ),
              ),
                  ],
                ),
              ),
              if (camposIncompletos > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: AppColors.danger, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'CAMPOS INCOMPLETOS: ($camposIncompletos)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar propietario, ID SEDATU, ejido…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _busqueda.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _busqueda = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _busqueda = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: Text(
                  'Filtros${_tieneFiltrosActivos ? ' ($_totalFiltrosActivos)' : ''}',
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => _showFiltros(context, allPredios),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$visible de ${_conteoProyecto(allPredios, _proyectoActual)} predios en $_proyectoActual',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          if (_tieneFiltrosActivos) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in _filtroEstructura)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('Estructura: $t'),
                        onDeleted: () => setState(() => _filtroEstructura = {..._filtroEstructura}..remove(t)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  for (final t in _filtroTramo)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('T/F/S: $t'),
                        onDeleted: () => setState(() => _filtroTramo = {..._filtroTramo}..remove(t)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  for (final t in _filtroTipo)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(t),
                        onDeleted: () => setState(() => _filtroTipo = {..._filtroTipo}..remove(t)),
                        backgroundColor: AppColors.tipoPropiedadColor(t).withValues(alpha: 0.15),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  for (final t in _filtroTipoLiberacion)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('Tipo liberacion: $t'),
                        onDeleted: () => setState(() => _filtroTipoLiberacion = {..._filtroTipoLiberacion}..remove(t)),
                        backgroundColor: AppColors.info.withValues(alpha: 0.15),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  for (final t in _filtroEstatus)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('Estatus: $t'),
                        onDeleted: () => setState(() => _filtroEstatus = {..._filtroEstatus}..remove(t)),
                        backgroundColor: t == 'Liberado'
                            ? AppColors.secondary.withValues(alpha: 0.15)
                            : AppColors.danger.withValues(alpha: 0.15),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  for (final t in _filtroRangoEstatus)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('Rango: $t'),
                        onDeleted: () => setState(() => _filtroRangoEstatus = {..._filtroRangoEstatus}..remove(t)),
                        backgroundColor: AppColors.rangoEstatusColor(t).withValues(alpha: 0.15),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTable(List<Predio> rows, Map<String, int> idPorPredio) {
    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.table_rows_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Sin registros para $_proyectoActual', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    const rawWidths = <double>[
       48, // ID (numeracion por proyecto)
       48, // ACCIONES (ver en mapa / editar / eliminar)
      180, // CLAVE
       90, // ESTRUCTURA
       50, // T/F/S
       90, // TIPO
       95, // ESTADO
      125, // MUNICIPIO
      120, // EJIDO
      150, // PROPIETARIOS
       72, // KM INICIO
       72, // KM FIN
       72, // KM EF
       80, // M²
      120, // TIPO LIBERACION
       46, // COP
      100, // FECHA DE LIBERACION
       46, // DWG
       46, // PLANO PDF
       46, // BDT
      110, // RANGO ESTATUS
       90, // ESTATUS
       54, // IDENT.
       54, // LEVANT.
       54, // NEGOC.
      150, // OBSERVACIONES
      100, // FECHA LIMITE DE PAGO
    ];

    const headers = <String>[
      'ID', '', 'CLAVE', 'ESTRUCTURA', 'T/F/S', 'TIPO', 'ESTADO', 'MUNICIPIO', 'EJIDO', 'PROPIETARIOS',
      'KM INICIO', 'KM FIN', 'KM EF', 'M²', 'TIPO\nLIBERACION',
      'COP/DOT', 'FECHA DE\nLIBERACION', 'DWG', 'PLANO\nPDF', 'BDT', 'RANGO\nESTATUS', 'ESTATUS',
      'IDENT.', 'LEVANT.', 'NEGOC.', 'OBSERVACIONES', 'FECHA LIMITE\nDE PAGO',
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final rawTotal = rawWidths.reduce((a, b) => a + b) + rawWidths.length * 1.0;
        final colWidths = List<double>.from(rawWidths);
        final totalWidth = math.max(constraints.maxWidth, rawTotal);

        return Scrollbar(
          controller: _horizontalScroll,
          thumbVisibility: true,
          notificationPredicate: (notification) => notification.depth == 0,
          child: SingleChildScrollView(
            controller: _horizontalScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              child: Scrollbar(
                controller: _verticalScroll,
                thumbVisibility: true,
                child: Column(
                  children: [
                    // Header fijo
                    _buildHeaderRow(headers, colWidths, totalWidth),
                    const Divider(height: 1, thickness: 1.5, color: AppColors.border),
                    // Filas
                    Expanded(
                      child: ListView.builder(
                        controller: _verticalScroll,
                        itemCount: rows.length,
                        itemExtent: 38,
                        itemBuilder: (ctx2, idx) => _buildDataRow(
                          rows[idx],
                          colWidths,
                          idx,
                          idPorPredio[rows[idx].id],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(List<String> headers, List<double> widths, double total) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.92),
      height: 40,
      child: Row(
        children: List.generate(headers.length, (i) {
          return _headerCell(headers[i], widths[i]);
        }),
      ),
    );
  }

  Widget _headerCell(String label, double width) {
    return Container(
      width: width,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white24, width: 0.5)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _savePredio(Predio previous, Predio updated) async {
    setState(() {
      _prediosOptimistas[updated.id] = updated;
    });

    if (updated.id.startsWith('local-')) {
      ref.read(localPrediosProvider.notifier).updatePredio(updated);
      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
      return;
    }

    try {
      final saved = await ref
          .read(prediosRepositoryProvider)
          .updatePredio(updated.id, updated.toMap());
      if (!mounted) return;
      setState(() {
        _prediosOptimistas[updated.id] = saved;
      });
      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prediosOptimistas[previous.id] = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el predio en la base de datos.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String? _pdfUrlFor(Predio predio) {
    final pdfUrl = predio.pdfUrl?.trim();
    if (pdfUrl != null && pdfUrl.isNotEmpty) return pdfUrl;

    final legacy = predio.copFirmado?.trim();
    if (legacy != null && legacy.isNotEmpty && legacy.startsWith('http')) {
      return legacy;
    }
    return null;
  }

  Uri? _normalizedHttpUrl(String url) {
    final value = _normalizeUrl(url);
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return uri;
  }

  String _copFechaLabel(Predio predio) {
    final fecha = predio.copFecha;
    if (fecha == null) return '-';
    return DateFormat('dd/MM/yyyy').format(fecha);
  }

  /// Celda de "Fecha de liberación": es un dato independiente del link de
  /// COP/DOT (ya no se autocompleta al vincular el PDF). Se puede llenar
  /// manualmente aquí, desde "Editar predio", o venir de un archivo
  /// importado.
  Widget _fechaLiberacionCell(Predio predio, double width) {
    return Tooltip(
      message: 'Editar fecha de liberación',
      child: InkWell(
        onTap: () => _showFechaLiberacionDialog(predio),
        child: Container(
          width: width,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Text(
            _copFechaLabel(predio),
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Future<void> _elegirFechaLiberacion(Predio predio) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: predio.copFecha ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('es', 'MX'),
      helpText: 'Fecha de liberación',
    );
    if (picked == null) return;
    await _savePredio(
      predio,
      predio.copyWith(
        copFecha: DateTime(picked.year, picked.month, picked.day),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _showFechaLiberacionDialog(Predio predio) async {
    final actual = predio.copFecha;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fecha de liberación'),
        content: Text(
          actual != null
              ? 'Fecha actual: ${DateFormat('dd/MM/yyyy').format(actual)}'
              : 'Sin fecha registrada.',
        ),
        actions: [
          if (actual != null)
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _savePredio(
                  predio,
                  predio.copyWith(clearCopFecha: true, updatedAt: DateTime.now()),
                );
              },
              child: const Text('Quitar fecha', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _elegirFechaLiberacion(predio);
            },
            child: Text(actual != null ? 'Cambiar fecha' : 'Elegir fecha'),
          ),
        ],
      ),
    );
  }

  String _fechaLimitePagoLabel(Predio predio) {
    final fecha = predio.fechaLimitePago;
    if (fecha == null) return '-';
    return DateFormat('dd/MM/yyyy').format(fecha);
  }

  /// Celda de "Fecha límite de pago": se puede llenar manualmente aquí,
  /// desde "Editar predio", o venir de un archivo importado.
  Widget _fechaLimitePagoCell(Predio predio, double width) {
    return Tooltip(
      message: 'Editar fecha límite de pago',
      child: InkWell(
        onTap: () => _showFechaLimitePagoDialog(predio),
        child: Container(
          width: width,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Text(
            _fechaLimitePagoLabel(predio),
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Future<void> _elegirFechaLimitePago(Predio predio) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: predio.fechaLimitePago ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('es', 'MX'),
      helpText: 'Fecha límite de pago',
    );
    if (picked == null) return;
    await _savePredio(
      predio,
      predio.copyWith(
        fechaLimitePago: DateTime(picked.year, picked.month, picked.day),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _showFechaLimitePagoDialog(Predio predio) async {
    final actual = predio.fechaLimitePago;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fecha límite de pago'),
        content: Text(
          actual != null
              ? 'Fecha actual: ${DateFormat('dd/MM/yyyy').format(actual)}'
              : 'Sin fecha registrada.',
        ),
        actions: [
          if (actual != null)
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _savePredio(
                  predio,
                  predio.copyWith(clearFechaLimitePago: true, updatedAt: DateTime.now()),
                );
              },
              child: const Text('Quitar fecha', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _elegirFechaLimitePago(predio);
            },
            child: Text(actual != null ? 'Cambiar fecha' : 'Elegir fecha'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPdfUrl(String url) async {
    final uri = _normalizedHttpUrl(url);
    if (uri == null) {
      throw Exception('La URL del PDF es invalida.');
    }
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened) {
      throw Exception('No se pudo abrir el PDF.');
    }
  }

  /// Etiqueta legible de cada uno de los 4 archivos gestionados desde
  /// "Editar archivos".
  String _archivoLabel(String campo) {
    switch (campo) {
      case 'copdot':
        return 'COP/DOT PDF';
      case 'dwg':
        return 'DWG';
      case 'planoPdf':
        return 'Plano PDF';
      case 'bdt':
        return 'BDT';
      default:
        return campo;
    }
  }

  String? _archivoUrlFor(Predio predio, String campo) {
    switch (campo) {
      case 'copdot':
        return _pdfUrlFor(predio);
      case 'dwg':
        final v = predio.poligonoDwg?.trim();
        return (v != null && v.isNotEmpty) ? v : null;
      case 'planoPdf':
        final v = predio.planoPdf?.trim();
        return (v != null && v.isNotEmpty) ? v : null;
      case 'bdt':
        final v = predio.bdt?.trim();
        return (v != null && v.isNotEmpty) ? v : null;
      default:
        return null;
    }
  }

  Future<void> _guardarArchivo(Predio predio, String campo, String url) async {
    final now = DateTime.now();
    Predio updated;
    switch (campo) {
      case 'copdot':
        // La "Fecha de liberación" ya NO se autocompleta al vincular el
        // link -es un dato independiente, editable por su cuenta desde su
        // propia columna o "Editar predio", o importable desde archivos-.
        updated = predio.copyWith(pdfUrl: url, copFirmado: url, updatedAt: now);
        break;
      case 'dwg':
        updated = predio.copyWith(poligonoDwg: url, updatedAt: now);
        break;
      case 'planoPdf':
        updated = predio.copyWith(planoPdf: url, updatedAt: now);
        break;
      case 'bdt':
        updated = predio.copyWith(bdt: url, updatedAt: now);
        break;
      default:
        return;
    }
    await _savePredio(predio, updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Archivo vinculado correctamente.'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  /// Limpia el link de un archivo. Usa las banderas `clearXxx` de
  /// `Predio.copyWith` -pasar `null` no alcanza, ver comentario en el
  /// modelo- para poder borrar el valor en vez de conservar el anterior.
  Future<void> _quitarArchivo(Predio predio, String campo) async {
    final now = DateTime.now();
    Predio updated;
    switch (campo) {
      case 'copdot':
        // No se limpia la fecha de liberación al quitar el link: son datos
        // independientes.
        updated = predio.copyWith(
          clearPdfUrl: true,
          clearCopFirmado: true,
          updatedAt: now,
        );
        break;
      case 'dwg':
        updated = predio.copyWith(clearPoligonoDwg: true, updatedAt: now);
        break;
      case 'planoPdf':
        updated = predio.copyWith(clearPlanoPdf: true, updatedAt: now);
        break;
      case 'bdt':
        updated = predio.copyWith(clearBdt: true, updatedAt: now);
        break;
      default:
        return;
    }
    await _savePredio(predio, updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Archivo eliminado.'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  Future<bool> _confirmarQuitarArchivo(String label) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text('¿Quitar el $label vinculado? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Diálogo unificado "Editar archivos": agrupa los 4 archivos-link del
  /// predio (COP/DOT PDF, DWG, Plano PDF, BDT) con acciones de
  /// Abrir/Agregar/Sustituir/Eliminar para cada uno.
  Future<void> _showEditarArchivosDialog(Predio predio) async {
    const campos = ['copdot', 'dwg', 'planoPdf', 'bdt'];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar archivos'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: campos.map((campo) {
                final label = _archivoLabel(campo);
                final url = _archivoUrlFor(predio, campo);
                final hasUrl = url != null;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 18,
                        color: hasUrl ? AppColors.secondary : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              hasUrl ? 'Vinculado' : 'Sin vincular',
                              style: TextStyle(
                                fontSize: 12,
                                color: hasUrl ? AppColors.secondary : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasUrl)
                        IconButton(
                          tooltip: 'Abrir',
                          icon: const Icon(Icons.open_in_new, size: 18),
                          onPressed: () async {
                            try {
                              await _openPdfUrl(url);
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
                              );
                            }
                          },
                        ),
                      IconButton(
                        tooltip: hasUrl ? 'Sustituir' : 'Agregar',
                        icon: Icon(hasUrl ? Icons.edit_outlined : Icons.add_link, size: 18),
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          final nuevaUrl = await _requestPdfUrl(
                            context,
                            initialValue: url ?? '',
                            titulo: hasUrl ? 'Sustituir $label' : 'Agregar $label',
                          );
                          if (nuevaUrl == null) return;
                          await _guardarArchivo(predio, campo, nuevaUrl);
                        },
                      ),
                      if (hasUrl)
                        IconButton(
                          tooltip: 'Eliminar',
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            final confirmado = await _confirmarQuitarArchivo(label);
                            if (!confirmado) return;
                            await _quitarArchivo(predio, campo);
                          },
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _requestPdfUrl(
    BuildContext context, {
    String initialValue = '',
    String titulo = 'Vincular URL de archivo',
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    final focusNode = FocusNode();
    String? error;

    Future<void> pasteFromClipboard(StateSetter setStateDialog) async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final clip = data?.text?.trim() ?? '';
      if (clip.isEmpty) return;
      _insertTextInController(ctrl, clip);
      setStateDialog(() {
        error = null;
      });
    }

    var requestedFocus = false;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            if (!requestedFocus) {
              requestedFocus = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (focusNode.canRequestFocus) {
                  focusNode.requestFocus();
                }
              });
            }

            return AlertDialog(
              title: Text(titulo),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: ctrl,
                      focusNode: focusNode,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.url],
                      enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        labelText: 'URL',
                        hintText: 'https://.../archivo.pdf',
                        helperText: 'Pega o escribe el link del archivo',
                        errorText: error,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Pegar',
                          icon: const Icon(Icons.content_paste),
                          onPressed: () => pasteFromClipboard(setStateDialog),
                        ),
                      ),
                      onFieldSubmitted: (_) {
                        final uri = _normalizedHttpUrl(ctrl.text);
                        if (uri == null) {
                          setStateDialog(() {
                            error = 'Ingresa una URL valida (http o https).';
                          });
                          return;
                        }
                        Navigator.of(dialogContext).pop(uri.toString());
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                      final uri = _normalizedHttpUrl(ctrl.text);

                      if (uri == null) {
                      setStateDialog(() {
                        error = 'Ingresa una URL valida (http o https).';
                      });
                      return;
                    }

                      Navigator.of(dialogContext).pop(uri.toString());
                  },
                  child: const Text('Guardar URL'),
                ),
              ],
            );
          },
        );
      },
    );

    focusNode.dispose();
    ctrl.dispose();
    return result;
  }

  void _insertTextInController(TextEditingController controller, String clip) {
    final value = controller.value;
    final selection = value.selection;
    final hasSelection =
        selection.isValid && selection.start >= 0 && selection.end >= 0;
    final start = hasSelection ? selection.start : value.text.length;
    final end = hasSelection ? selection.end : value.text.length;

    final newText = value.text.replaceRange(start, end, clip);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + clip.length),
    );
  }

  String _normalizeUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value);
    if (hasScheme) return value;
    return 'https://$value';
  }

  /// Campos obligatorios de Gestión (ver requerimiento de alerta de
  /// campos incompletos): si alguno falta, la celda muestra un signo de
  /// admiración rojo y el predio cuenta para el contador del topbar.
  bool _campoTextoVacio(String? value) => value == null || value.trim().isEmpty;

  bool _tieneCamposIncompletos(Predio p) =>
      _campoTextoVacio(p.claveCatastral) ||
      _campoTextoVacio(p.propietarioNombre) ||
      _campoTextoVacio(p.estructura) ||
      _campoTextoVacio(p.estado) ||
      _campoTextoVacio(p.municipio) ||
      _campoTextoVacio(p.ejido) ||
      p.kmInicio == null ||
      p.kmFin == null ||
      p.kmEfectivos == null ||
      p.superficie == null;

  Widget _buildDataRow(Predio p, List<double> widths, int idx, int? idProyecto) {
    final isEven = idx % 2 == 0;
    final tipoColor = AppColors.tipoPropiedadColor(p.tipoPropiedad);
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8F9FA),
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // ID (numeracion estable dentro del proyecto actual)
          _dataCell(
            idProyecto?.toString() ?? '-',
            widths[0],
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          // ACCIONES (ver en mapa / editar / eliminar)
          _accionesCell(p, widths[1]),
          // CLAVE
          _dataCell(p.claveCatastral, widths[2],
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              color: tipoColor.withValues(alpha: 0.08),
              requerido: true),
            // ESTRUCTURA
            _dataCell(p.estructura ?? '-', widths[3], requerido: true),
          // T/F/S
            _tramoBadgeCell(p.tramo, widths[4]),
          // TIPO
            _tipoBadgeCell(p.tipoPropiedad, tipoColor, widths[5]),
          // ESTADO
          _dataCell((p.estado == null || p.estado!.isEmpty) ? '-' : p.estado!, widths[6], requerido: true),
          // MUNICIPIO
          _dataCell((p.municipio == null || p.municipio!.isEmpty) ? '-' : p.municipio!, widths[7], requerido: true),
          // EJIDO
          _dataCell(p.ejido ?? '-', widths[8], requerido: true),
          // PROPIETARIOS
          _dataCell(p.propietarioNombre ?? '-', widths[9], requerido: true),
          // KM INICIO
          _kmCell(p.kmInicio, widths[10], requerido: true),
          // KM FIN
          _kmCell(p.kmFin, widths[11], requerido: true),
          // KM EF
          _numCell(p.kmEfectivos, widths[12], decimals: 4, requerido: true),
          // M²
          _numCell(p.superficie, widths[13], decimals: 2, requerido: true),
          // TIPO LIBERACION
          _dataCell(p.tipoLiberacion ?? '-', widths[14]),
          // COP/DOT PDF (icono de estado)
          _archivoLinkCell(p, widths[15], campo: 'copdot'),
          // FECHA DE LIBERACION (editable: calendario)
          _fechaLiberacionCell(p, widths[16]),
          // DWG
          _archivoLinkCell(p, widths[17], campo: 'dwg'),
          // PLANO PDF
          _archivoLinkCell(p, widths[18], campo: 'planoPdf'),
          // BDT
          _archivoLinkCell(p, widths[19], campo: 'bdt'),
          // RANGO ESTATUS
          _rangoEstatusCell(p, widths[20]),
          // ESTATUS
          _estatusCell(p, widths[21]),
          // IDENTIFICACION (tappable)
          _tappableBoolCell(
            p.identificacion, widths[22],
            onTap: () => _savePredio(
              p,
              p.copyWith(
                identificacion: !p.identificacion,
                updatedAt: DateTime.now(),
              ),
            ),
          ),
          // LEVANTAMIENTO (tappable)
          _tappableBoolCell(
            p.levantamiento, widths[23],
            onTap: () => _savePredio(
              p,
              p.copyWith(
                levantamiento: !p.levantamiento,
                updatedAt: DateTime.now(),
              ),
            ),
          ),
          // NEGOCIACION (tappable)
          _tappableBoolCell(
            p.negociacion, widths[24],
            onTap: () => _savePredio(
              p,
              p.copyWith(
                negociacion: !p.negociacion,
                updatedAt: DateTime.now(),
              ),
            ),
          ),
          // OBSERVACIONES (antes situacion social)
          _dataCell(p.situacionSocial ?? '-', widths[25]),
          _fechaLimitePagoCell(p, widths[26]),
        ],
      ),
    );
  }

  Widget _buildLiberadosAlert(List<Predio> pendientes) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Marcar predios liberados con Identificación, Levantamiento y Negociación',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Hay ${pendientes.length} predio(s) liberado(s) sin los tres campos completos.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _autocompletandoLiberados
                        ? null
                        : () => setState(() => _dismissLiberadosAlert = true),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 116,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        fixedSize: const Size(116, 40),
                        minimumSize: const Size(116, 40),
                        maximumSize: const Size(116, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: _autocompletandoLiberados
                          ? null
                          : () => _autocompletarLiberadosPendientes(pendientes),
                      child: _autocompletandoLiberados
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Aceptar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _autocompletarLiberadosPendientes(List<Predio> pendientes) async {
    setState(() => _autocompletandoLiberados = true);

    var actualizados = 0;
    var errores = 0;
    final repo = ref.read(prediosRepositoryProvider);

    for (final predio in pendientes) {
      final updated = predio.copyWith(
        identificacion: true,
        levantamiento: true,
        negociacion: true,
        updatedAt: DateTime.now(),
      );

      try {
        if (updated.id.startsWith('local-')) {
          ref.read(localPrediosProvider.notifier).updatePredio(updated);
        } else {
          final saved = await repo.updatePredio(updated.id, updated.toMap());
          _prediosOptimistas[updated.id] = saved;
        }
        actualizados++;
      } catch (_) {
        errores++;
      }
    }

    if (!mounted) return;

    setState(() {
      _dismissLiberadosAlert = true;
      _autocompletandoLiberados = false;
    });

    ref.invalidate(prediosListProvider);
    ref.invalidate(prediosMapaProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errores == 0
              ? 'Autocompletado aplicado en $actualizados predio(s).'
              : 'Autocompletado: $actualizados actualizado(s), $errores con error.',
        ),
        backgroundColor: errores == 0 ? AppColors.secondary : AppColors.danger,
      ),
    );
  }

  Widget _rangoEstatusCell(Predio predio, double width) {
    final color = AppColors.rangoEstatusColor(predio.rangoEstatus);
    // Negociacion y Con ingreso son amarillo: el texto amarillo se pierde
    // sobre un fondo amarillo claro, asi que para estos dos se usa un
    // fondo gris (el texto se mantiene en su color indicado).
    final rangoNorm = predio.rangoEstatus.toUpperCase().trim();
    final esAmarillo = rangoNorm == 'NEGOCIACION' || rangoNorm == 'CON INGRESO';
    final backgroundColor = esAmarillo
        ? Colors.grey.withValues(alpha: 0.35)
        : color.withValues(alpha: 0.15);

    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          predio.rangoEstatus,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _estatusCell(Predio predio, double width) {
    final estatus = Predio.estatusSimplificado(predio.rangoEstatus);
    final color = estatus == 'Liberado' ? AppColors.secondary : AppColors.danger;

    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          estatus,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Columna de acciones: un menú flotante con "Ver en mapa", "Editar
  /// predio" y "Eliminar registro" (antes eran dos columnas separadas).
  Widget _accionesCell(Predio p, double width) {
    // Un predio también cuenta como vinculado si comparte polígono con otro
    // (afectación repetida vinculada por clave a un predio vectorial: ver
    // `polygonRefId`), aunque no tenga su propia `geometry`.
    final vinculado = p.poligonoInsertado ||
        p.geometry != null ||
        (p.polygonRefId != null && p.polygonRefId!.trim().isNotEmpty);

    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Acciones',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.menu, size: 18, color: AppColors.primary),
        onSelected: (value) {
          switch (value) {
            case 'mapa':
              if (!vinculado) {
                ref.read(manualVincularPredioIdProvider.notifier).state = p.id;
                context.go('/mapa');
              } else {
                ref.read(focusPredioIdProvider.notifier).state = p.id;
                context.go('/mapa');
              }
              break;
            case 'editar':
              context.push('/predios/${p.id}/editar');
              break;
            case 'archivos':
              _showEditarArchivosDialog(p);
              break;
            case 'eliminar':
              _confirmarEliminarPredio(p);
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'mapa',
            child: Row(
              children: [
                Icon(
                  vinculado ? Icons.link_rounded : Icons.link_off_rounded,
                  size: 16,
                  color: vinculado ? AppColors.secondary : AppColors.danger,
                ),
                const SizedBox(width: 10),
                Text(vinculado ? 'Ver en mapa' : 'Vincular en mapa'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'editar',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Editar predio'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'archivos',
            child: Row(
              children: [
                Icon(Icons.attach_file, size: 16, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Editar archivos'),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          const PopupMenuItem(
            value: 'eliminar',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                SizedBox(width: 10),
                Text('Eliminar registro', style: TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminarPredio(Predio p) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar predio'),
        content: Text(
          '¿Eliminar el registro "${p.claveCatastral}" de Gestión? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await _eliminarPredio(p);
  }

  Future<void> _eliminarPredio(Predio p) async {
    try {
      if (p.id.startsWith('local-')) {
        ref.read(localPrediosProvider.notifier).removePredio(p.id);
      } else {
        await ref.read(prediosRepositoryProvider).eliminarPredioConReasignacion(p.id);
        ref.invalidate(prediosListProvider);
        ref.invalidate(prediosMapaProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Predio "${p.claveCatastral}" eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el predio: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Widget _dataCell(String text, double width, {TextStyle? style, Color? color, bool requerido = false}) {
    final vacio = requerido && (text.trim().isEmpty || text.trim() == '-');
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        border: const Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: vacio
          ? const Icon(Icons.error, color: AppColors.danger, size: 16)
          : Text(
        text,
        style: style ?? const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  /// Celda para "km inicio"/"km fin": siempre se muestran en formato PK
  /// (placa kilométrica) "KM+M", sin importar si el archivo de origen traía
  /// el dato como "12+359" o como "12.359" -son la misma distancia-.
  Widget _kmCell(double? value, double width, {bool requerido = false}) {
    final vacio = requerido && value == null;
    final text = value == null ? '-' : norm.formatKmPk(value);
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: vacio
          ? const Icon(Icons.error, color: AppColors.danger, size: 16)
          : Text(
        text,
        style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _numCell(double? value, double width, {int decimals = 2, bool requerido = false}) {
    final vacio = requerido && value == null;
    final text = value == null
        ? '-'
        : decimals == 4
            ? _nf4.format(value)
            : _nf.format(value);
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: vacio
          ? const Icon(Icons.error, color: AppColors.danger, size: 16)
          : Text(
        text,
        style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tappableBoolCell(bool value, double width,
      {Color? trueColor, Color? falseColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: double.infinity,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Icon(
          value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: value
              ? (trueColor ?? AppColors.secondary)
              : (falseColor ?? Colors.grey.shade300),
        ),
      ),
    );
  }

  /// Celda de icono-link para cada uno de los 4 archivos gestionados desde
  /// "Editar archivos" (COP/DOT PDF, DWG, Plano PDF, BDT). Tocar cualquiera
  /// de las 4 columnas abre el mismo diálogo unificado, donde se puede
  /// Abrir/Agregar/Sustituir/Eliminar cualquiera de los 4.
  Widget _archivoLinkCell(Predio predio, double width, {required String campo}) {
    final hasUrl = _archivoUrlFor(predio, campo) != null;
    final label = _archivoLabel(campo);

    return Tooltip(
      message: hasUrl ? 'Editar $label' : 'Agregar $label',
      child: InkWell(
        onTap: () => _showEditarArchivosDialog(predio),
        child: Container(
          width: width,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Icon(
            Icons.link,
            size: 18,
            color: hasUrl ? AppColors.secondary : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _tramoBadgeCell(String tramo, double width) {
    final tramoLabel = tramo.trim().isEmpty ? '-' : tramo.trim();
    const colors = {
      'T1': Color(0xFF3498DB),
      'T2': Color(0xFF9B59B6),
      'T3': Color(0xFFE67E22),
      'T4': Color(0xFF1ABC9C),
    };
    final c = colors[tramoLabel] ?? Colors.grey;
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          tramoLabel,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
        ),
      ),
    );
  }

  Widget _tipoBadgeCell(String tipo, Color color, double width) {
    final label = tipo == 'DOMINIO PLENO' ? 'D.PLENO' : tipo;
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  void _showFiltros(BuildContext context, List<Predio> allPredios) {
    final tramo = Set<String>.of(_filtroTramo);
    final tipo = Set<String>.of(_filtroTipo);
    final tipoLiberacion = Set<String>.of(_filtroTipoLiberacion);
    final estatus = Set<String>.of(_filtroEstatus);
    final rangoEstatus = Set<String>.of(_filtroRangoEstatus);
    final estructura = Set<String>.of(_filtroEstructura);
    final tramos = _opcionesTramoProyecto(allPredios);
    final tipos = _opcionesTipoProyecto(allPredios);
    final tiposLiberacion = _opcionesTipoLiberacionProyecto(allPredios);
    final estructuras = _opcionesEstructuraProyecto(allPredios);
    final tieneDatosProyecto =
        allPredios.any((predio) => _predioProyecto(predio) == _proyectoActual);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DefaultTextStyle.merge(
          style: const TextStyle(color: AppColors.textPrimary),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Filtros',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      onPressed: () {
                        setS(() {
                          tramo.clear();
                          tipo.clear();
                          tipoLiberacion.clear();
                          estatus.clear();
                          rangoEstatus.clear();
                          estructura.clear();
                        });
                      },
                      child: const Text('Limpiar todo'),
                    ),
                    IconButton(
                      color: AppColors.textPrimary,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: AppColors.border),
                if (!tieneDatosProyecto)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No hay registros para $_proyectoActual. Importa o selecciona otro proyecto para ver opciones.',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                Text(
                  'Estructura',
                  style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: estructuras
                      .map(
                        (t) => FilterChip(
                          label: Text(t),
                          labelStyle: const TextStyle(color: AppColors.textPrimary),
                          checkmarkColor: AppColors.primary,
                          selected: estructura.contains(t),
                          onSelected: (v) => setS(() => v ? estructura.add(t) : estructura.remove(t)),
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'T/F/S',
                  style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: tramos
                      .map(
                        (t) => FilterChip(
                          label: Text(t),
                          labelStyle: const TextStyle(color: AppColors.textPrimary),
                          checkmarkColor: AppColors.primary,
                          selected: tramo.contains(t),
                          onSelected: (v) => setS(() => v ? tramo.add(t) : tramo.remove(t)),
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tipo de Propiedad',
                  style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: tipos
                      .map(
                        (t) => FilterChip(
                          label: Text(t),
                          labelStyle: const TextStyle(color: AppColors.textPrimary),
                          checkmarkColor: AppColors.textPrimary,
                          selected: tipo.contains(t),
                          onSelected: (v) => setS(() => v ? tipo.add(t) : tipo.remove(t)),
                          selectedColor: AppColors.tipoPropiedadColor(t).withValues(alpha: 0.2),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tipo de liberacion',
                  style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: tiposLiberacion
                      .map(
                        (t) => FilterChip(
                          label: Text(t),
                          labelStyle: const TextStyle(color: AppColors.textPrimary),
                          checkmarkColor: AppColors.info,
                          selected: tipoLiberacion.contains(t),
                          onSelected: (v) => setS(() => v ? tipoLiberacion.add(t) : tipoLiberacion.remove(t)),
                          selectedColor: AppColors.info.withValues(alpha: 0.2),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Estatus',
                  style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('Liberado'),
                      labelStyle: const TextStyle(color: AppColors.textPrimary),
                      checkmarkColor: AppColors.secondary,
                      selected: estatus.contains('Liberado'),
                      onSelected: (v) => setS(() => v ? estatus.add('Liberado') : estatus.remove('Liberado')),
                      selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                    ),
                    FilterChip(
                      label: const Text('No liberado'),
                      labelStyle: const TextStyle(color: AppColors.textPrimary),
                      checkmarkColor: AppColors.danger,
                      selected: estatus.contains('No liberado'),
                      onSelected: (v) => setS(() => v ? estatus.add('No liberado') : estatus.remove('No liberado')),
                      selectedColor: AppColors.danger.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Rango de estatus',
                  style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: Predio.rangoEstatusOpciones
                      .map(
                        (t) => FilterChip(
                          label: Text(t),
                          labelStyle: const TextStyle(color: AppColors.textPrimary),
                          checkmarkColor: AppColors.rangoEstatusColor(t),
                          selected: rangoEstatus.contains(t),
                          onSelected: (v) => setS(() => v ? rangoEstatus.add(t) : rangoEstatus.remove(t)),
                          selectedColor: AppColors.rangoEstatusColor(t).withValues(alpha: 0.2),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _filtroTramo = tramo;
                        _filtroTipo = tipo;
                        _filtroTipoLiberacion = tipoLiberacion;
                        _filtroEstatus = estatus;
                        _filtroRangoEstatus = rangoEstatus;
                        _filtroEstructura = estructura;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Aplicar filtros'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
