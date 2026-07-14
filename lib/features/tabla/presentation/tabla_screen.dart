import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/browser_download.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../../predios/data/predios_repository.dart';
import '../../predios/models/predio.dart';
import '../../predios/providers/local_predios_provider.dart';
import '../../predios/providers/predios_provider.dart';
import '../../propietarios/providers/local_propietarios_provider.dart';
import '../../propietarios/providers/propietarios_provider.dart';

class TablaScreen extends ConsumerStatefulWidget {
  const TablaScreen({super.key});

  @override
  ConsumerState<TablaScreen> createState() => _TablaScreenState();
}


class _TablaScreenState extends ConsumerState<TablaScreen> {
  static const _proyectos = ['TQI', 'TSNL', 'TAP', 'TQM'];

  final _searchCtrl = TextEditingController();
  final _verticalScroll = ScrollController();
  final _horizontalScroll = ScrollController();
  final Map<String, Predio> _prediosOptimistas = {};
  List<Predio> _ultimosPredios = const [];

  String _proyectoActual = 'TQI';
  String _busqueda = '';
  String? _filtroTramo;
  String? _filtroTipo;
  String? _filtroTipoLiberacion;
  String? _filtroEstatus; // 'Liberado' | 'No liberado' | null

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
  String? _lastTramo;
  String? _lastTipo;
  String? _lastTipoLiberacion;
  String? _lastEstatus;
  String? _lastBusqueda;
  List<Predio>? _lastFiltered;

  List<Predio> _applyFilters(List<Predio> all) {
    final shouldRecompute = _lastAll != all ||
        _lastProyecto != _proyectoActual ||
        _lastTramo != _filtroTramo ||
        _lastTipo != _filtroTipo ||
      _lastTipoLiberacion != _filtroTipoLiberacion ||
        _lastEstatus != _filtroEstatus ||
        _lastBusqueda != _busqueda;
    if (!shouldRecompute && _lastFiltered != null) {
      return _lastFiltered!;
    }
    final filtered = all.where((p) {
      if (_predioProyecto(p) != _proyectoActual) return false;
      if (_filtroTramo != null && p.tramo != _filtroTramo) return false;
      if (_filtroTipo != null && p.tipoPropiedad != _filtroTipo) return false;
      if (_filtroEstatus != null) {
        final estatus = p.cop ? 'Liberado' : 'No liberado';
        if (estatus != _filtroEstatus) return false;
      }
      if (_filtroTipoLiberacion != null) {
        final tipoLiberacion = _normalizarTipoLiberacion(p.tipoLiberacion);
        if (tipoLiberacion != _filtroTipoLiberacion) return false;
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
    _lastTramo = _filtroTramo;
    _lastTipo = _filtroTipo;
    _lastTipoLiberacion = _filtroTipoLiberacion;
    _lastEstatus = _filtroEstatus;
    _lastBusqueda = _busqueda;
    _lastFiltered = filtered;
    return filtered;
  }

  String _normalizarTipoLiberacion(String? value) {
    final text = (value ?? '').trim().toUpperCase();
    if (text.isEmpty || text == '-') return 'SIN TIPO';
    return text;
  }

  String _predioProyecto(Predio predio) {
    final proyectoDirecto = predio.proyecto?.trim().toUpperCase();
    if (proyectoDirecto != null && _proyectos.contains(proyectoDirecto)) {
      return proyectoDirecto;
    }

    final clave = predio.claveCatastral.trim().toUpperCase();
    final compact = clave.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.startsWith('TQI') || compact.startsWith('QI')) return 'TQI';
    if (compact.startsWith('TSNL') || compact.startsWith('SNL') || compact.startsWith('SL')) return 'TSNL';
    if (compact.startsWith('TAP') || compact.startsWith('AP')) return 'TAP';
    if (compact.startsWith('TQM') || compact.startsWith('QM')) return 'TQM';

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
    final prediosAsync = ref.watch(prediosListProvider);
    Widget content;
    if (prediosAsync.isLoading) {
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
            _buildTopBar(0, const []),
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
              _filtroTramo = null;
              _filtroTipo = null;
              _filtroTipoLiberacion = null;
              _filtroEstatus = null;
              _currentPage = 0;
            });
            ref.read(gestionProyectoProvider.notifier).state = null;
          });
        }

        final liberadosIncompletos = filtered
            .where((p) => p.cop && (!p.identificacion || !p.levantamiento || !p.negociacion))
            .toList(growable: false);
        if (liberadosIncompletos.isEmpty) {
          _dismissLiberadosAlert = false;
        }

        content = Column(
          children: [
            _buildTopBar(filtered.length, allPredios),
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
                    child: _buildTable(rowsToRender),
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
          icon: const Icon(Icons.download),
          tooltip: 'Exportar a Excel',
          onPressed: () {
            final prediosAsync = ref.read(prediosListProvider);
            final prediosList = prediosAsync.asData?.value ?? [];
            final allPredios = prediosList.map((p) => _prediosOptimistas[p.id] ?? p).toList();
            final filtered = _applyFilters(allPredios);
            _exportToExcel(filtered);
          },
        ),
      ],
      child: content,
    );
  }

  Future<void> _exportToExcel(List<Predio> predios) async {
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
        'CLAVE', 'PROYECTO', 'T/F/S', 'TIPO', 'ESTRUCTURA', 'ESTADO', 'MUNICIPIO', 
        'EJIDO', 'PROPIETARIO', 'KM INICIO', 'KM FIN', 'KM EFECTIVOS',
        'SUPERFICIE M2', 'COP', 'FECHA COP', 'ESTATUS',
        'IDENTIFICACION', 'LEVANTAMIENTO', 'NEGOCIACION', 'OBSERVACIONES'
      ];
      
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
      }
      
      // Data rows
      for (var row = 0; row < predios.length; row++) {
        final p = predios[row];
        final rowData = [
          p.claveCatastral,
          _predioProyecto(p),
          p.tramo,
          p.tipoPropiedad,
          p.estructura ?? '',
          p.estado ?? '',
          p.municipio ?? '',
          p.ejido ?? '',
          p.propietarioNombre ?? '',
          p.kmInicio?.toString() ?? '',
          p.kmFin?.toString() ?? '',
          p.kmEfectivos?.toString() ?? '',
          p.superficie?.toString() ?? '',
          p.cop ? 'SI' : 'NO',
          p.copFecha != null ? '${p.copFecha!.day}/${p.copFecha!.month}/${p.copFecha!.year}' : '',
          p.cop ? 'Liberado' : 'No liberado',
          p.identificacion ? 'SI' : 'NO',
          p.levantamiento ? 'SI' : 'NO',
          p.negociacion ? 'SI' : 'NO',
          p.situacionSocial ?? '',
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
        // Para mobile/desktop, usar el método original
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Exportación de Gestión $_proyectoActual',
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

  Widget _buildTopBar(int visible, List<Predio> allPredios) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
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
                      value: _proyectoActual,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      items: _proyectos.map((proyecto) {
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
                  'Filtros${_filtroTramo != null || _filtroTipo != null || _filtroTipoLiberacion != null || _filtroEstatus != null ? ' ✓' : ''}',
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
          if (_filtroTramo != null || _filtroTipo != null || _filtroTipoLiberacion != null || _filtroEstatus != null) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_filtroTramo != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('T/F/S: $_filtroTramo'),
                        onDeleted: () => setState(() => _filtroTramo = null),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (_filtroTipo != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(_filtroTipo!),
                        onDeleted: () => setState(() => _filtroTipo = null),
                        backgroundColor: AppColors.tipoPropiedadColor(_filtroTipo!).withValues(alpha: 0.15),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (_filtroTipoLiberacion != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('Tipo liberacion: $_filtroTipoLiberacion'),
                        onDeleted: () => setState(() => _filtroTipoLiberacion = null),
                        backgroundColor: AppColors.info.withValues(alpha: 0.15),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (_filtroEstatus != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('Estatus: $_filtroEstatus'),
                        onDeleted: () => setState(() => _filtroEstatus = null),
                        backgroundColor: _filtroEstatus == 'Liberado'
                            ? AppColors.secondary.withValues(alpha: 0.15)
                            : AppColors.danger.withValues(alpha: 0.15),
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

  Widget _buildTable(List<Predio> rows) {
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
       44, // ACCIONES
       55, // VER MAPA
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
       92, // FECHA
       90, // ESTATUS
       54, // IDENT.
       54, // LEVANT.
       54, // NEGOC.
      150, // OBSERVACIONES
    ];

    const headers = <String>[
      '', 'MAPA', 'CLAVE', 'ESTRUCTURA', 'T/F/S', 'TIPO', 'ESTADO', 'MUNICIPIO', 'EJIDO', 'PROPIETARIOS',
      'KM INICIO', 'KM FIN', 'KM EF', 'M²', 'TIPO\nLIBERACION',
      'COP/DOT', 'FECHA', 'ESTATUS',
      'IDENT.', 'LEVANT.', 'NEGOC.', 'OBSERVACIONES',
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
                        itemBuilder: (ctx2, idx) => _buildDataRow(rows[idx], colWidths, idx),
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

  Future<void> _handleCopPdfTap(Predio predio) async {
    final existingUrl = _pdfUrlFor(predio);
    if (existingUrl != null) {
      await _openPdfUrl(existingUrl);
      return;
    }

    final url = await _requestPdfUrl(
      context,
      initialValue: predio.pdfUrl?.trim() ?? '',
    );
    if (url == null) return;

    await _savePredio(
      predio,
      predio.copyWith(
        pdfUrl: url,
        copFirmado: url,
        copFecha: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL del archivo vinculada correctamente.'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  Future<String?> _requestPdfUrl(
    BuildContext context, {
    String initialValue = '',
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
              title: const Text('Vincular URL de archivo'),
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

  Widget _buildDataRow(Predio p, List<double> widths, int idx) {
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
          // ACCIONES
          _actionCell(p, widths[0]),
          // VER EN MAPA
          _mapCell(p, widths[1]),
          // CLAVE
          _dataCell(p.claveCatastral, widths[2],
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              color: tipoColor.withValues(alpha: 0.08)),
            // ESTRUCTURA
            _dataCell(p.estructura ?? '-', widths[3]),
          // T/F/S
            _tramoBadgeCell(p.tramo, widths[4]),
          // TIPO
            _tipoBadgeCell(p.tipoPropiedad, tipoColor, widths[5]),
          // ESTADO
          _dataCell((p.estado == null || p.estado!.isEmpty) ? '-' : p.estado!, widths[6]),
          // MUNICIPIO
          _dataCell((p.municipio == null || p.municipio!.isEmpty) ? '-' : p.municipio!, widths[7]),
          // EJIDO
          _dataCell(p.ejido ?? '-', widths[8]),
          // PROPIETARIOS
          _dataCell(p.propietarioNombre ?? '-', widths[9]),
          // KM INICIO
          _numCell(p.kmInicio, widths[10], decimals: 4),
          // KM FIN
          _numCell(p.kmFin, widths[11], decimals: 4),
          // KM EF
          _numCell(p.kmEfectivos, widths[12], decimals: 4),
          // M²
          _numCell(p.superficie, widths[13], decimals: 2),
          // TIPO LIBERACION
          _dataCell(p.tipoLiberacion ?? '-', widths[14]),
          // COP/DOT PDF (icono de estado)
          _copPdfIndicatorCell(p, widths[15]),
          // FECHA COP/DOT
          _dataCell(_copFechaLabel(p), widths[16]),
          // ESTATUS
          _estatusCell(p, widths[17]),
          // IDENTIFICACION (tappable)
          _tappableBoolCell(
            p.identificacion, widths[18],
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
            p.levantamiento, widths[19],
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
            p.negociacion, widths[20],
            onTap: () => _savePredio(
              p,
              p.copyWith(
                negociacion: !p.negociacion,
                updatedAt: DateTime.now(),
              ),
            ),
          ),
          // OBSERVACIONES (antes situacion social)
          _dataCell(p.situacionSocial ?? '-', widths[21]),
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

  Widget _estatusCell(Predio predio, double width) {
    final estatus = predio.cop ? 'Liberado' : 'No liberado';
    final color = predio.cop ? AppColors.secondary : AppColors.danger;

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

  Widget _actionCell(Predio p, double width) {
    return InkWell(
      onTap: () => context.push('/predios/${p.id}/editar'),
      child: Container(
        width: width,
        height: double.infinity,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
      ),
    );
  }

  /// Botón "Ver en Mapa": navega al mapa y hace fly-to al predio.
  Widget _mapCell(Predio p, double width) {
    final vinculado = p.poligonoInsertado || p.geometry != null;
    return Tooltip(
      message: vinculado
          ? 'Vinculado: ver en mapa'
          : 'No vinculado: vincular manualmente',
      child: InkWell(
        onTap: () {
          if (!vinculado) {
            ref.read(manualVincularPredioIdProvider.notifier).state = p.id;
            context.go('/mapa');
            return;
          }
          ref.read(focusPredioIdProvider.notifier).state = p.id;
          context.go('/mapa');
        },
        child: Container(
          width: width,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Icon(
            vinculado ? Icons.link_rounded : Icons.link_off_rounded,
            size: 16,
            color: vinculado ? AppColors.secondary : AppColors.danger,
          ),
        ),
      ),
    );
  }

  Widget _dataCell(String text, double width, {TextStyle? style, Color? color}) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        border: const Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Text(
        text,
        style: style ?? const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _numCell(double? value, double width, {int decimals = 2}) {
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
      child: Text(
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

  Widget _copPdfIndicatorCell(Predio predio, double width) {
    final hasPdf = _pdfUrlFor(predio) != null;
    final iconColor = hasPdf ? AppColors.secondary : Colors.grey.shade400;
    final tooltip = hasPdf
        ? 'Abrir archivo vinculado'
        : 'Vincular URL de archivo';

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _handleCopPdfTap(predio),
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
            color: iconColor,
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
    String? tramo = _filtroTramo;
    String? tipo = _filtroTipo;
    String? tipoLiberacion = _filtroTipoLiberacion;
    String? estatus = _filtroEstatus;
    final tramos = _opcionesTramoProyecto(allPredios);
    final tipos = _opcionesTipoProyecto(allPredios);
    final tiposLiberacion = _opcionesTipoLiberacionProyecto(allPredios);
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
                          tramo = null;
                          tipo = null;
                          tipoLiberacion = null;
                          estatus = null;
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
                          selected: tramo == t,
                          onSelected: (v) => setS(() => tramo = v ? t : null),
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
                          selected: tipo == t,
                          onSelected: (v) => setS(() => tipo = v ? t : null),
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
                          selected: tipoLiberacion == t,
                          onSelected: (v) => setS(() => tipoLiberacion = v ? t : null),
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
                      selected: estatus == 'Liberado',
                      onSelected: (v) => setS(() => estatus = v ? 'Liberado' : null),
                      selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                    ),
                    FilterChip(
                      label: const Text('No liberado'),
                      labelStyle: const TextStyle(color: AppColors.textPrimary),
                      checkmarkColor: AppColors.danger,
                      selected: estatus == 'No liberado',
                      onSelected: (v) => setS(() => estatus = v ? 'No liberado' : null),
                      selectedColor: AppColors.danger.withValues(alpha: 0.2),
                    ),
                  ],
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
