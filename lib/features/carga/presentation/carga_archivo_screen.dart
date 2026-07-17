import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/firebase/firebase_config.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../../predios/providers/predios_provider.dart';
import '../../predios/providers/local_predios_provider.dart';
import '../../predios/data/predios_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../predios/models/predio.dart';
import '../../predios/models/propietario.dart';
import '../../propietarios/providers/propietarios_provider.dart';
import '../../propietarios/providers/local_propietarios_provider.dart';
import '../../mapa/providers/mapa_state_cleanup.dart';
import '../data/archivos_geojson_repository.dart';
import '../providers/carga_provider.dart';
import '../services/geojson_background_parser.dart';
import '../services/sincronizacion_service.dart';
import '../services/xlsx_import_service.dart';
import '../utils/archive_exporter.dart';
import '../utils/file_download.dart';
import '../utils/geojson_mapper.dart';
import '../utils/imported_file_cleanup.dart';

class CargaArchivoScreen extends ConsumerStatefulWidget {
  const CargaArchivoScreen({super.key});

  @override
  ConsumerState<CargaArchivoScreen> createState() => _CargaArchivoScreenState();
}

class _CargaArchivoScreenState extends ConsumerState<CargaArchivoScreen> {
  bool _loading = false;
  bool _sincronizando = false;
  String? _eliminandoFileId;
  bool _eliminandoTodos = false;
  List<Map<String, dynamic>> _preview = [];
  PlatformFile? _archivoSeleccionado;
  Map<String, dynamic>? _geoJsonData;
  SincronizacionResultado? _syncResultado;
  XlsxParseResult? _xlsxParseResult;
  /// Mapa campo → N° de features que lo contienen (detectado al parsear).
  Map<String, int> _camposDetectados = {};
  int _totalFeatures = 0;

  // Encuesta previa de importacion
  String? _tipoArchivoImportacion; // geojson | xlsx
  String? _contenidoGeoJsonImportacion; // predios | envolvente | pks

  void _mostrarSnackBar(String mensaje, {bool exito = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: exito ? null : AppColors.danger,
        duration: Duration(seconds: exito ? 5 : 8),
      ),
    );
  }

  // Se usa Overlay + Timer propio (en vez de ScaffoldMessenger.showSnackBar)
  // porque este aviso se muestra justo antes de un context.go() de navegación:
  // el Scaffold que aloja el SnackBar puede desmontarse a mitad de su
  // animación y dejar el aviso visualmente "pegado" en pantalla sin que su
  // temporizador de auto-cierre llegue a dispararse.
  void _mostrarAvisoConAccion(
    BuildContext context, {
    required String mensaje,
    required String accionLabel,
    required VoidCallback onAccion,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    final timer = Timer(const Duration(seconds: 5), () => entry.remove());
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        bottom: 24,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF323232),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(mensaje, style: const TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () {
                    timer.cancel();
                    entry.remove();
                    onAccion();
                  },
                  child: Text(
                    accionLabel,
                    style: const TextStyle(color: Colors.lightBlueAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }

  bool _yaCargoDesdeDB = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarArchivosDesdeBD());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_yaCargoDesdeDB) {
      // Se carga una vez por instancia del widget; initState ya lo dispara.
      return;
    }
    // Si el widget ya existía (volvimos a esta pantalla), recargamos desde BD.
    _cargarArchivosDesdeBD();
  }

  /// Administrador ve los archivos de todos; Gestor solo ve los que él importó.
  bool _isAdminUser() {
    final perfil = ref.read(currentUserPerfilProvider);
    final user = ref.read(currentUserProvider) ?? FirebaseAuth.instance.currentUser;
    return isPerfilAdministrador(perfil) || isAdminApproverUser(user);
  }

  String? get _currentUid =>
      (ref.read(currentUserProvider) ?? FirebaseAuth.instance.currentUser)?.uid;
  String? get _currentUserEmail =>
      (ref.read(currentUserProvider) ?? FirebaseAuth.instance.currentUser)?.email;

  /// Administrador ve todo. Gestor ve los suyos + los que no tienen dueño
  /// registrado (importados antes de asociar `created_by_uid`), para que
  /// ningún archivo quede invisible/imborrable por falta de ese dato.
  List<ImportedFile> _visibleFiles(List<ImportedFile> files) {
    if (_isAdminUser()) return files;
    final uid = _currentUid;
    return files
        .where((f) => f.createdByUid == null || f.createdByUid == uid)
        .toList();
  }

  Future<void> _cargarArchivosDesdeBD() async {
    try {
      final repo = ref.read(archivosGeoJsonRepositoryProvider);
      final rawList = await repo.getArchivos();
      final bdFiles = _visibleFiles(rawList
          .map((m) {
            try {
              return ImportedFile.fromBD(m);
            } catch (_) {
              return null;
            }
          })
          .whereType<ImportedFile>()
          .toList());
      if (!mounted) return;
      ref.read(cargaProvider.notifier).initFromBD(bdFiles);
      if (bdFiles.isEmpty) {
        clearImportedMapState(ref.read);
        ref.read(importacionAsyncProvider.notifier).reset();
      }
      _yaCargoDesdeDB = true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error cargando archivos desde Firestore: $e');
    }
  }

  // Tamaño máximo de archivo: 2 MB = 2,097,152 bytes
  static const int _maxFileSizeBytes = 2 * 1024 * 1024;
  static const int _maxEnvolventeRingPoints = 220;
  static const int _minEnvolventeRingPoints = 64;
  static const int _maxEnvolventeTotalPoints = 14000;
  static const int _envolventeUltraThreshold = 30000;
  static const int _envolventeExtremeThreshold = 60000;

  Future<void> _seleccionarArchivo() async {
    final encuesta = await _mostrarEncuestaPreviaImportacion();
    if (encuesta == null) return;

    final tipoArchivo = encuesta.tipoArchivo;
    final allowedExtensions = tipoArchivo == 'xlsx'
        ? ['xlsx', 'xlsl']
        : ['geojson', 'json'];

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    // Extraer extensión del nombre (file.extension puede no estar disponible en web)
    final ext = file.name.split('.').last.toLowerCase();

    // Validar que sea un archivo permitido
    if (!allowedExtensions.contains(ext)) {
      if (!mounted) return;
      final formatos = tipoArchivo == 'xlsx'
          ? '.xlsx o .xlsl'
          : '.geojson o .json';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Archivo no soportado para el tipo seleccionado. Usa $formatos',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Validar tamaño de archivo (máximo 2 MB)
    final fileSize = file.size;
    if (fileSize > _maxFileSizeBytes) {
      final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El archivo es muy grande (${sizeMB} MB). Máximo permitido: 2 MB',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _tipoArchivoImportacion = encuesta.tipoArchivo;
      _contenidoGeoJsonImportacion = encuesta.contenidoGeoJson;
      _archivoSeleccionado = file;
      _geoJsonData = null;
      _preview = [];
      _xlsxParseResult = null;
      _syncResultado = null;
      _camposDetectados = {};
      _totalFeatures = 0;
      _loading = true;
    });

    try {
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.readStream != null) {
        final collected = <int>[];
        await for (final chunk in file.readStream!) {
          collected.addAll(chunk);
        }
        bytes = Uint8List.fromList(collected);
      }

      if (bytes == null) {
        if (!mounted) return;
        _mostrarSnackBar('No se pudo leer el archivo seleccionado.', exito: false);
        return;
      }

      // Mostrar indicador de progreso para archivos grandes
      if (fileSize > 500 * 1024) { // Mayor a 500KB
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Cargando archivo...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );
      }

      if (tipoArchivo == 'xlsx') {
        await _parsearXlsx(bytes);
      } else {
        await _parsearGeoJSON(bytes);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _parsearXlsx(Uint8List bytes) async {
    try {
      final service = ref.read(xlsxImportServiceProvider);
      final parseResult = await service.parseInBackground(bytes);
      if (!mounted) return;
      setState(() {
        _geoJsonData = null;
        _preview = [];
        _syncResultado = null;
        _camposDetectados = {};
        _totalFeatures = 0;
        _xlsxParseResult = parseResult;
      });
      _mostrarSnackBar('${parseResult.totalRows} filas detectadas en ${parseResult.hojas.length} hoja(s) compatibles.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _xlsxParseResult = null);
      _mostrarSnackBar('No se pudo leer el XLSX: $e', exito: false);
    }
  }

  Future<void> _parsearGeoJSON(Uint8List bytes) async {
    try {
      final parseResult = await parseGeoJsonInBackground(
        bytes: bytes,
        fileName: _archivoSeleccionado?.name ?? 'archivo.geojson',
      );

      if (!mounted) return;
      setState(() {
        _geoJsonData = {
          'type': 'FeatureCollection',
          'features': parseResult.features,
        };
        _preview = parseResult.preview;
        _totalFeatures = parseResult.totalFeatures;
        _camposDetectados = parseResult.camposDetectados;
      });
      _mostrarSnackBar('${parseResult.totalFeatures} features encontrados');
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Error al leer el archivo: $e', exito: false);
    }
  }

  Future<_ImportSurveyResult?> _mostrarEncuestaPreviaImportacion() {
    final initialTipo = _tipoArchivoImportacion ?? 'geojson';
    final initialContenido = _contenidoGeoJsonImportacion ?? 'predios';

    return showDialog<_ImportSurveyResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var tipo = initialTipo;
        var contenido = initialContenido;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Encuesta previa a la importacion'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Tipo de archivo',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: tipo,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'geojson', child: Text('GeoJson')),
                        DropdownMenuItem(value: 'xlsx', child: Text('XLSX')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          tipo = value;
                          if (tipo != 'geojson') {
                            contenido = 'predios';
                          }
                        });
                      },
                    ),
                    if (tipo == 'geojson') ...[
                      const SizedBox(height: 16),
                      const Text(
                        '2. Contenido de archivo',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: contenido,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'predios', child: Text('Predios')),
                          DropdownMenuItem(value: 'envolvente', child: Text('Envolvente')),
                          DropdownMenuItem(value: 'pks', child: Text('PKs')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => contenido = value);
                        },
                      ),
                    ],
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
                    Navigator.of(dialogContext).pop(
                      _ImportSurveyResult(
                        tipoArchivo: tipo,
                        contenidoGeoJson: tipo == 'geojson' ? contenido : null,
                      ),
                    );
                  },
                  child: const Text('Continuar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Acciones sobre el GeoJSON ──────────────────────────────

  /// Extrae la lista de features del GeoJSON parseado.
  List<Map<String, dynamic>> _extraerFeatures() {
    final featuresList = _geoJsonData!['features'];
    if (featuresList is! List) return [];
    return featuresList
        .map(_asStringDynamicMap)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Sincroniza, vincula y persiste en BD; después renderiza en mapa.
  Future<void> _guardarYVerEnMapa({
    String? forcedGeoJsonContent,
  }) async {
    if (_geoJsonData == null) return;
    final features = _extraerFeatures();
    if (features.isEmpty) return;

    final nombre = _archivoSeleccionado?.name ??
        'archivo_${DateTime.now().millisecondsSinceEpoch}';

    setState(() => _sincronizando = true);
    ref.read(importacionAsyncProvider.notifier).iniciar(
      total: features.length,
      etapa: 'Sincronizando',
    );

    try {
      if (forcedGeoJsonContent == 'envolvente') {
        await _guardarEnvolventeSoloMapa(nombre: nombre, features: features);
        return;
      }

      if (forcedGeoJsonContent == 'pks') {
        await _guardarPksSoloMapa(nombre: nombre, features: features);
        return;
      }

      if (forcedGeoJsonContent == null) {
        if (_isEnvolventeImport(fileName: nombre, features: features)) {
          await _guardarEnvolventeSoloMapa(nombre: nombre, features: features);
          return;
        }

        if (_isPksPointImport(fileName: nombre, features: features)) {
          await _guardarPksSoloMapa(nombre: nombre, features: features);
          return;
        }
      }

      final syncService = ref.read(sincronizacionServiceProvider);
      final resultado = await syncService.sincronizar(
        features,
        onProgress: (procesados, total) {
          ref.read(importacionAsyncProvider.notifier).actualizar(
            procesados: procesados,
            total: total,
            etapa: 'Sincronizando',
          );
        },
      );

      if (!mounted) return;

      // Guardar archivo en la BD
      String? bdId;
        try {
          final archivosRepo = ref.read(archivosGeoJsonRepositoryProvider);
          final saved = await archivosRepo.saveArchivo(
            nombre: nombre,
            features: resultado.features,
            sincronizado: true,
            encontrados: resultado.encontrados,
            creados: resultado.creados,
            errores: resultado.errores,
            createdByUid: _currentUid,
            createdByEmail: _currentUserEmail,
          );
          bdId = saved['id'] as String?;
        } catch (_) {
          // Si falla el guardado del archivo, continuar igualmente.
        }

      setState(() {
        _syncResultado = resultado;
        _sincronizando = false;
      });
      if (resultado.errores > 0 && resultado.creados == 0 && resultado.encontrados == 0) {
        final detalle = resultado.mensajesError.isNotEmpty
            ? resultado.mensajesError.first
            : 'Verifica que las colecciones y reglas de Firestore estén configuradas en Firebase.';
        _mostrarSnackBar('No se pudo registrar en Gestión.\n$detalle', exito: false);
      } else if (resultado.errores > 0) {
        _mostrarSnackBar(
          '${resultado.creados} guardados, ${resultado.errores} con error.\n'
          '${resultado.mensajesError.isNotEmpty ? resultado.mensajesError.first : ""}',
          exito: false,
        );
      }

      // Fallback local: si no se pudo persistir en BD, registrar en Gestión local.
      final totalGestion = resultado.creados + resultado.encontrados;
      if (totalGestion == 0) {
        final insertadosLocales = ref
            .read(localPrediosProvider.notifier)
            .upsertManyFromGeoJsonFeatures(features);

        ref.invalidate(prediosListProvider);
        ref.invalidate(prediosMapaProvider);

        final proyectoDetectado =
            GeoJsonMapper.detectarProyectoDesdeFeatures(features);
        final proyectoObjetivo =
            proyectoDetectado ?? ref.read(proyectoActivoProvider);
        if (proyectoObjetivo != null) {
          ref.read(gestionProyectoProvider.notifier).state = proyectoObjetivo;
        }

        ref.read(importacionAsyncProvider.notifier).completar(
          total: features.length,
          etapa: 'Completado',
        );
        if (mounted) {
          _mostrarSnackBar('BD no disponible. $insertadosLocales predio(s) registrados en Gestión local.');
          context.go('/tabla');
        }
      }

      ref.read(cargaProvider.notifier).addFile(
        nombre,
        resultado.features,
        bdId: bdId,
        guardadoEnBD: bdId != null,
        sincronizado: true,
        encontrados: resultado.encontrados,
        creados: resultado.creados,
        errores: resultado.errores,
        createdByUid: _currentUid,
        createdByEmail: _currentUserEmail,
      );

      ref.read(importedFeaturesProvider.notifier).state = resultado.features;

      // Refrescar Gestión y Mapa con los nuevos registros creados
      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);

      // Detectar proyecto predominante con GeoJsonMapper y auto-seleccionarlo en Gestión
      if (resultado.creados > 0 || resultado.encontrados > 0) {
        final proyectoDetectado =
            GeoJsonMapper.detectarProyectoDesdeFeatures(resultado.features);
        final proyectoObjetivo =
            proyectoDetectado ?? ref.read(proyectoActivoProvider);
        if (proyectoObjetivo != null) {
          ref.read(gestionProyectoProvider.notifier).state = proyectoObjetivo;
        }

        ref.read(importacionAsyncProvider.notifier).completar(
          total: features.length,
          etapa: 'Completado',
        );

        // Navegar a Gestión para que el usuario vea las filas inyectadas
        if (mounted) {
          _mostrarAvisoConAccion(
            context,
            mensaje:
                '${resultado.creados} nuevo(s) + ${resultado.encontrados} actualizado(s) en Gestión',
            accionLabel: 'Ver Mapa',
            onAccion: () => context.go('/mapa'),
          );
          context.go('/tabla');
        }
      }
    } catch (e) {
      if (!mounted) return;
      final insertadosLocales = ref
          .read(localPrediosProvider.notifier)
          .upsertManyFromGeoJsonFeatures(features);
      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);

      final proyectoDetectado =
          GeoJsonMapper.detectarProyectoDesdeFeatures(features);
      final proyectoObjetivo =
          proyectoDetectado ?? ref.read(proyectoActivoProvider);
      if (proyectoObjetivo != null) {
        ref.read(gestionProyectoProvider.notifier).state = proyectoObjetivo;
      }

      if (insertadosLocales > 0) {
        ref.read(importacionAsyncProvider.notifier).completar(
          total: features.length,
          etapa: 'Completado',
        );
      } else {
        ref.read(importacionAsyncProvider.notifier).fallar(
          procesados: 0,
          total: features.length,
          etapa: 'Error',
          mensaje: e.toString(),
        );
      }
      setState(() => _sincronizando = false);
      _mostrarSnackBar(
        'Error de BD: $e\n$insertadosLocales predio(s) registrados en Gestión local.',
        exito: insertadosLocales > 0,
      );
      if (insertadosLocales > 0) {
        context.go('/tabla');
      }
    }
  }

  /// Envía un archivo de la tabla al mapa
  void _verEnMapaDesdeTabla(String fileId) {
    final importedFiles = ref.read(cargaProvider);
    final file = importedFiles.firstWhere((f) => f.id == fileId);
    if (_isEnvolventeImport(fileName: file.name, features: file.features)) {
      ref.read(importedFeaturesProvider.notifier).state = file.features;
      ref.read(pksPointFeaturesProvider.notifier).state = const [];
    } else if (_isPksPointImport(fileName: file.name, features: file.features)) {
      ref.read(pksPointFeaturesProvider.notifier).state = file.features;
      ref.read(importedFeaturesProvider.notifier).state = const [];
    } else {
      ref.read(importedFeaturesProvider.notifier).state = file.features;
      ref.read(pksPointFeaturesProvider.notifier).state = const [];
    }
    context.go('/mapa');
  }

  /// Elimina un archivo: del provider en memoria y, si tiene bdId, también de la BD.
  ///
  /// El archivo se mantiene en la lista (con spinner) hasta que termina de
  /// borrarse de Gestión/BD, en vez de quitarse de inmediato: así el usuario
  /// ve que la operación sigue en curso y no necesita reintentar creyendo
  /// que no hizo nada.
  Future<void> _eliminarArchivo(ImportedFile file) async {
    if (_eliminandoFileId != null || _eliminandoTodos) return;
    setState(() => _eliminandoFileId = file.id);
    try {
      final currentImported = ref.read(importedFeaturesProvider);
      final shouldClearMap = shouldClearImportedMapAfterFileDeletion(
        currentImported: currentImported,
        fileFeatures: file.features,
      );
      final currentPks = ref.read(pksPointFeaturesProvider);
      final shouldClearPks = _shouldClearPksPointsAfterFileDeletion(
        currentPks: currentPks,
        fileFeatures: file.features,
      );
      final claves = extractClavesFromFeatures(file.features);

      final eliminadosGestion = await _eliminarPrediosDeGestionPorClaves(claves);

      ref.read(cargaProvider.notifier).removeFile(file.id);
      if (shouldClearMap) {
        ref.read(importedFeaturesProvider.notifier).state = const [];
        ref.read(importacionAsyncProvider.notifier).reset();
      }
      if (shouldClearPks) {
        ref.read(pksPointFeaturesProvider.notifier).state = const [];
      }

      if (file.guardadoEnBD && file.bdId != null) {
        try {
          final repo = ref.read(archivosGeoJsonRepositoryProvider);
          await repo.deleteArchivo(file.bdId!);
        } catch (_) {
          // Error silencioso: el archivo ya fue quitado de la UI.
        }
      }

      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
      if (mounted) {
        _mostrarSnackBar(
          eliminadosGestion > 0
              ? 'Archivo eliminado y $eliminadosGestion predio(s) removido(s) de Gestión.'
              : 'Archivo eliminado de Gestión y Mapa.',
        );
      }
    } finally {
      if (mounted) setState(() => _eliminandoFileId = null);
    }
  }

  Future<void> _eliminarTodos(List<ImportedFile> files) async {
    if (_eliminandoFileId != null || _eliminandoTodos) return;
    setState(() => _eliminandoTodos = true);
    try {
      final claves = <String>{};
      for (final file in files) {
        claves.addAll(extractClavesFromFeatures(file.features));
      }

      final eliminadosGestion = await _eliminarPrediosDeGestionPorClaves(claves);

      ref.read(cargaProvider.notifier).clearAll();
      ref.read(importedFeaturesProvider.notifier).state = const [];
      ref.read(pksPointFeaturesProvider.notifier).state = const [];
      ref.read(importacionAsyncProvider.notifier).reset();

      try {
        final repo = ref.read(archivosGeoJsonRepositoryProvider);
        final ids = files.map((f) => f.bdId).whereType<String>().toList();
        await repo.deleteAll(ids);
      } catch (_) {}

      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
      if (mounted) {
        _mostrarSnackBar(
          eliminadosGestion > 0
              ? 'Archivos eliminados y $eliminadosGestion predio(s) removido(s) de Gestión.'
              : 'Archivos eliminados de Gestión y Mapa.',
        );
      }
    } finally {
      if (mounted) setState(() => _eliminandoTodos = false);
    }
  }

  Future<int> _eliminarPrediosDeGestionPorClaves(Set<String> claves) async {
    if (claves.isEmpty) return 0;

    var eliminados = 0;

    eliminados +=
        ref.read(localPrediosProvider.notifier).removeByClaves(claves);

    try {
      // Se consulta el repositorio directo (sin los filtros de proyecto/
      // búsqueda activos en la UI de Gestión) para no dejar sin eliminar
      // predios del archivo que caen fuera del filtro seleccionado en ese
      // momento.
      final repo = ref.read(prediosRepositoryProvider);
      final canAccessAllProjects = ref.read(canAccessAllProjectsProvider);
      final allowedProjects = ref.read(currentUserAssignedProjectsProvider);
      final predios = await repo.getPredios(
        proyectosPermitidos: canAccessAllProjects ? null : allowedProjects,
        limit: 100000,
      );
      final toDelete = predios.where((p) {
        final clave = p.claveCatastral.trim().toUpperCase();
        return !p.id.startsWith('local-') && claves.contains(clave);
      }).toList(growable: false);

      for (final predio in toDelete) {
        try {
          await repo.deletePredio(predio.id);
          eliminados++;
        } catch (_) {
          // Continuar con los siguientes predios aunque alguno falle.
        }
      }
    } catch (_) {
      // Si la consulta remota falla, al menos ya se limpió local.
    }

    return eliminados;
  }

  Future<void> _inyectarXlsxEnTablas() async {
    final parseResult = _xlsxParseResult;
    if (parseResult == null) return;

    if (!FirebaseConfig.isConfigured) {
      _mostrarSnackBar(
        'Firebase no esta configurado. Define FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID y FIREBASE_PROJECT_ID.',
        exito: false,
      );
      return;
    }

    setState(() => _sincronizando = true);

    try {
      final service = ref.read(xlsxImportServiceProvider);
      final resultado = await service.importar(parseResult);

      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
      ref.invalidate(propietariosListProvider);

      if (!mounted) return;
      setState(() => _sincronizando = false);
      if (resultado.errores == 0) {
        _mostrarSnackBar(
          'Inyección completada: ${resultado.procesados} fila(s), ${resultado.creados} creada(s), '
          '${resultado.actualizados} actualizada(s).',
        );
      } else {
        _mostrarSnackBar(
          resultado.mensajes.isNotEmpty
              ? resultado.mensajes.first
              : 'Algunas filas no pudieron inyectarse (${resultado.errores} error(es)).',
          exito: false,
        );
      }

      // Persistir el archivo XLSX en la BD y registrarlo en la lista
      if (_archivoSeleccionado != null) {
        String? bdId;
        try {
          final archivosRepo = ref.read(archivosGeoJsonRepositoryProvider);
          final saved = await archivosRepo.saveArchivo(
            nombre: _archivoSeleccionado!.name,
            features: const [],
            rowCount: resultado.procesados,
            sincronizado: true,
            encontrados: resultado.actualizados,
            creados: resultado.creados,
            errores: resultado.errores,
            createdByUid: _currentUid,
            createdByEmail: _currentUserEmail,
          );
          bdId = saved['id'] as String?;
        } catch (_) {
          // Si falla el guardado del archivo, continuar igualmente.
        }
        ref.read(cargaProvider.notifier).addFile(
          _archivoSeleccionado!.name,
          const [],
          bdId: bdId,
          guardadoEnBD: bdId != null,
          sincronizado: true,
          creados: resultado.creados,
          encontrados: resultado.actualizados,
          errores: resultado.errores,
          rowCount: resultado.procesados,
          createdByUid: _currentUid,
          createdByEmail: _currentUserEmail,
        );
      }

      if (resultado.errores > 0 && mounted) {
        // error SnackBar already shown above
      }

      if (mounted) {
        context.go('/tabla');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sincronizando = false);
      _mostrarSnackBar(
        !FirebaseConfig.isConfigured
          ? 'Firebase no está configurado. Define FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID y FIREBASE_PROJECT_ID antes de inyectar el XLSX.'
            : 'Error al inyectar XLSX: $e',
        exito: false,
      );
    }
  }

  Future<void> _inyectarXlsxLocal(XlsxParseResult parseResult) async {
    setState(() => _sincronizando = true);

    var procesados = 0;
    var creados = 0;
    var actualizados = 0;
    var errores = 0;
    final mensajes = <String>[];

    final localPropietarios = ref.read(localPropietariosProvider.notifier);
    final localPredios = ref.read(localPrediosProvider.notifier);
    final prediosParaUpsert = <Predio>[];

    try {
      for (final hoja in parseResult.hojas) {
        if (hoja.tabla == XlsxTargetTable.propietarios) {
          for (final row in hoja.rows) {
            procesados++;
            try {
              final existente = _findLocalPropietario(
                ref.read(localPropietariosProvider),
                row,
              );
              localPropietarios.upsertFromData(row);
              if (existente == null) {
                creados++;
              } else {
                actualizados++;
              }
            } catch (e) {
              errores++;
              if (mensajes.length < 8) {
                mensajes.add('Hoja ${hoja.hoja}: $e');
              }
            }
          }
          continue;
        }

        for (var i = 0; i < hoja.rows.length; i++) {
          final row = hoja.rows[i];
          procesados++;

          try {
            final clave = row['clave_catastral']?.toString().trim() ?? '';
            if (clave.isEmpty) {
              errores++;
              if (mensajes.length < 8) {
                mensajes.add('Hoja ${hoja.hoja}: fila sin clave_catastral.');
              }
              continue;
            }

            Propietario? propietario;
            final propietarioData = _buildLocalPropietarioData(row);
            if (propietarioData.isNotEmpty) {
              propietario = localPropietarios.upsertFromData(propietarioData);
            }

            final existente = ref.read(localPrediosProvider).any(
                  (item) => item.claveCatastral == clave,
                ) ||
                prediosParaUpsert.any((item) => item.claveCatastral == clave);

            prediosParaUpsert.add(
              Predio(
                id: 'local-xlsx-${clave.replaceAll(' ', '_')}-${i + 1}',
                claveCatastral: clave,
                propietarioNombre: propietario?.nombreCompleto ??
                    row['propietario_nombre']?.toString().trim(),
                tramo: row['tramo']?.toString().trim().isNotEmpty == true
                    ? row['tramo'].toString().trim()
                  : '',
                tipoPropiedad: _normalizeTipoPropiedad(
                    row['tipo_propiedad']?.toString().trim(),
                ),
                estructura: _optionalText(row['estructura']),
                ejido: _optionalText(row['ejido']),
                kmInicio: _toDouble(row['km_inicio']),
                kmFin: _toDouble(row['km_fin']),
                kmLineales: _toDouble(row['km_lineales']),
                kmEfectivos: _toDouble(row['km_efectivos']),
                superficie: _toDouble(row['superficie']),
                cop: _toBool(row['cop']),
                proyecto: _optionalText(row['proyecto']),
                poligonoInsertado: _toBool(row['poligono_insertado']),
                identificacion: _toBool(row['identificacion']),
                levantamiento: _toBool(row['levantamiento']),
                negociacion: _toBool(row['negociacion']),
                latitud: _toDouble(row['latitud']),
                longitud: _toDouble(row['longitud']),
                propietarioId: propietario?.id,
                propietario: propietario,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            if (existente) {
              actualizados++;
            } else {
              creados++;
            }
          } catch (e) {
            errores++;
            if (mensajes.length < 8) {
              mensajes.add('Hoja ${hoja.hoja}: $e');
            }
          }
        }
      }

      localPredios.upsertMany(prediosParaUpsert);
      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
      ref.invalidate(propietariosListProvider);

      // Detectar proyecto dominante entre los predios importados
      const codigosProyecto = ['TQI', 'TSNL', 'TAP', 'TQM'];
      String? proyectoDetectado;

      // 1) Ver qué proyecto aparece más veces en el campo proyecto de los predios
      final conteo = <String, int>{};
      for (final predio in prediosParaUpsert) {
        final p = predio.proyecto?.trim().toUpperCase() ?? '';
        if (codigosProyecto.contains(p)) {
          conteo[p] = (conteo[p] ?? 0) + 1;
        }
      }
      if (conteo.isNotEmpty) {
        proyectoDetectado =
            conteo.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      }

      // 2) Si no se detectó, intentar desde el nombre de las hojas del Excel
      if (proyectoDetectado == null) {
        for (final hoja in parseResult.hojas) {
          final upper = hoja.hoja.toUpperCase();
          for (final code in codigosProyecto) {
            final regex =
                RegExp(r'(^|[^A-Z0-9])' + code + r'([^A-Z0-9]|$)');
            if (regex.hasMatch(upper)) {
              proyectoDetectado = code;
              break;
            }
          }
          if (proyectoDetectado != null) break;
        }
      }

      // Navegar al tab del proyecto detectado (o TQI si no se pudo determinar,
      // ya que _predioProyecto en TablaScreen usa TQI como fallback por defecto)
      ref.read(gestionProyectoProvider.notifier).state =
          proyectoDetectado ?? 'TQI';

      if (!mounted) return;
      setState(() => _sincronizando = false);
      if (errores == 0) {
        _mostrarSnackBar(
          'Inyección local completada: $procesados fila(s), $creados creada(s), $actualizados actualizada(s).',
        );
      } else {
        _mostrarSnackBar(
          mensajes.isNotEmpty
              ? mensajes.first
              : 'Algunas filas no pudieron inyectarse en modo local ($errores error(es)).',
          exito: false,
        );
      }

      // Registrar en la lista de archivos importados
      if (_archivoSeleccionado != null) {
        String? bdId;
        try {
          final archivosRepo = ref.read(archivosGeoJsonRepositoryProvider);
          final saved = await archivosRepo.saveArchivo(
            nombre: _archivoSeleccionado!.name,
            features: const [],
            rowCount: procesados,
            sincronizado: true,
            encontrados: actualizados,
            creados: creados,
            errores: errores,
            createdByUid: _currentUid,
            createdByEmail: _currentUserEmail,
          );
          bdId = saved['id'] as String?;
        } catch (_) {
          // En modo local sin BD/Sheets, continuar sin persistir el registro.
        }
        ref.read(cargaProvider.notifier).addFile(
          _archivoSeleccionado!.name,
          const [],
          bdId: bdId,
          guardadoEnBD: bdId != null,
          sincronizado: true,
          creados: creados,
          encontrados: actualizados,
          errores: errores,
          rowCount: procesados,
          createdByUid: _currentUid,
          createdByEmail: _currentUserEmail,
        );
      }

      if (errores > 0 && mounted) {
        // error SnackBar already shown above
      }

      if (mounted) {
        context.go('/tabla');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sincronizando = false);
      _mostrarSnackBar('Error al inyectar XLSX en modo local: $e', exito: false);
    }
  }

  Map<String, dynamic> _buildLocalPropietarioData(Map<String, dynamic> row) {
    final out = <String, dynamic>{};

    final nombre = _optionalText(row['propietario_nombre']);
    if (nombre != null) {
      out['nombre_completo'] = nombre;
    }

    final rfc = _optionalText(row['rfc_propietario']);
    if (rfc != null) {
      out['rfc'] = rfc;
    }

    final curp = _optionalText(row['curp_propietario']);
    if (curp != null) {
      out['curp'] = curp;
    }

    final telefono = _optionalText(row['telefono_propietario']);
    if (telefono != null) {
      out['telefono'] = telefono;
    }

    final correo = _optionalText(row['correo_propietario']);
    if (correo != null) {
      out['correo'] = correo;
    }

    return out;
  }

  Propietario? _findLocalPropietario(
    List<Propietario> propietarios,
    Map<String, dynamic> row,
  ) {
    final rfc = _optionalText(row['rfc']);
    if (rfc != null) {
      for (final propietario in propietarios) {
        if ((propietario.rfc ?? '').trim().toUpperCase() == rfc.toUpperCase()) {
          return propietario;
        }
      }
    }

    final nombre = _optionalText(row['nombre']);
    final apellidos = _optionalText(row['apellidos']) ?? '';
    final nombreCompleto = _optionalText(row['nombre_completo']);
    final comparador = (nombreCompleto ?? [nombre, apellidos].whereType<String>().join(' '))
      .trim()
      .toUpperCase();
    if (comparador.isEmpty) {
      return null;
    }

    for (final propietario in propietarios) {
      if (propietario.nombreCompleto.trim().toUpperCase() == comparador) {
        return propietario;
      }
    }

    return null;
  }

  String? _optionalText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') {
      return null;
    }
    return text;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = _optionalText(value)?.toLowerCase();
    return text == 'true' || text == '1' || text == 'si' || text == 'sí' || text == 'yes';
  }

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _guardarPksSoloMapa({
    required String nombre,
    required List<Map<String, dynamic>> features,
  }) async {
    final normalizedFeatures = _normalizePksPointFeatures(features);
    try {
      String? bdId;
      try {
        final archivosRepo = ref.read(archivosGeoJsonRepositoryProvider);
        final saved = await archivosRepo.saveArchivo(
          nombre: nombre,
          features: normalizedFeatures,
          sincronizado: false,
          encontrados: 0,
          creados: 0,
          errores: 0,
          createdByUid: _currentUid,
          createdByEmail: _currentUserEmail,
        );
        bdId = saved['id'] as String?;
      } catch (_) {
        // Si falla el guardado del archivo, continuar con mapa en memoria.
      }

      ref.read(cargaProvider.notifier).addFile(
        nombre,
        normalizedFeatures,
        bdId: bdId,
        guardadoEnBD: bdId != null,
        sincronizado: false,
        encontrados: 0,
        creados: 0,
        errores: 0,
        createdByUid: _currentUid,
        createdByEmail: _currentUserEmail,
      );

      ref.read(pksPointFeaturesProvider.notifier).state = normalizedFeatures;
      ref.read(importedFeaturesProvider.notifier).state = const [];
      ref.read(importacionAsyncProvider.notifier).completar(
        total: normalizedFeatures.length,
        etapa: 'Completado PKS',
      );

      if (!mounted) return;
      setState(() => _sincronizando = false);
      _mostrarSnackBar(
        'Archivo PKS detectado: ${normalizedFeatures.length} punto(s) cargado(s) solo en mapa.',
      );
      context.go('/mapa');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sincronizando = false);
      ref.read(importacionAsyncProvider.notifier).fallar(
        procesados: 0,
        total: normalizedFeatures.length,
        etapa: 'Error PKS',
        mensaje: e.toString(),
      );
      _mostrarSnackBar('No se pudo cargar el archivo PKS: $e', exito: false);
    }
  }

  Future<void> _guardarEnvolventeSoloMapa({
    required String nombre,
    required List<Map<String, dynamic>> features,
  }) async {
    final normalizedFeatures = _normalizeEnvolventeFeatures(features);
    try {
      String? bdId;
      try {
        final archivosRepo = ref.read(archivosGeoJsonRepositoryProvider);
        final saved = await archivosRepo.saveArchivo(
          nombre: nombre,
          features: normalizedFeatures,
          sincronizado: false,
          encontrados: 0,
          creados: 0,
          errores: 0,
          createdByUid: _currentUid,
          createdByEmail: _currentUserEmail,
        );
        bdId = saved['id'] as String?;
      } catch (_) {
        // Si falla el guardado del archivo, continuar con mapa en memoria.
      }

      ref.read(cargaProvider.notifier).addFile(
        nombre,
        normalizedFeatures,
        bdId: bdId,
        guardadoEnBD: bdId != null,
        sincronizado: false,
        encontrados: 0,
        creados: 0,
        errores: 0,
        createdByUid: _currentUid,
        createdByEmail: _currentUserEmail,
      );

      // ENVOLVENTE se renderiza solo en mapa; no pasa por Gestión.
      ref.read(importedFeaturesProvider.notifier).state = normalizedFeatures;
      ref.read(pksPointFeaturesProvider.notifier).state = const [];
      ref.read(importacionAsyncProvider.notifier).completar(
        total: normalizedFeatures.length,
        etapa: 'Completado ENVOLVENTE',
      );

      if (!mounted) return;
      setState(() => _sincronizando = false);
      _mostrarSnackBar(
        'Archivo ENVOLVENTE detectado: ${normalizedFeatures.length} feature(s) cargado(s) solo en mapa.',
      );
      context.go('/mapa');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sincronizando = false);
      ref.read(importacionAsyncProvider.notifier).fallar(
        procesados: 0,
        total: normalizedFeatures.length,
        etapa: 'Error ENVOLVENTE',
        mensaje: e.toString(),
      );
      _mostrarSnackBar('No se pudo cargar el archivo ENVOLVENTE: $e', exito: false);
    }
  }

  bool _isEnvolventeImport({
    required String fileName,
    required List<Map<String, dynamic>> features,
  }) {
    if (features.isEmpty) return false;

    final fromName = _normalizeValue(fileName).contains('ENVOLVENTE');
    final fromProps = features.any(_featureMentionsEnvolvente);
    return fromName || fromProps;
  }

  bool _featureMentionsEnvolvente(Map<String, dynamic> feature) {
    final rawProps = feature['properties'];
    if (rawProps is! Map) return false;
    final props = Map<String, dynamic>.from(rawProps);

    final direct = _pickTextByAliases(props, const [
      'capa',
      'tipo_capa',
      'categoria',
      'nombre_capa',
      'layer',
      'tipo',
      'descripcion',
    ]);
    if (direct != null && _normalizeValue(direct).contains('ENVOLVENTE')) {
      return true;
    }

    for (final entry in props.entries) {
      final keyNorm = _normalizeValue(entry.key);
      if (keyNorm.contains('ENVOLVENTE')) {
        return true;
      }

      final value = entry.value?.toString();
      if (value == null) continue;
      if (_normalizeValue(value).contains('ENVOLVENTE')) {
        return true;
      }
    }

    return false;
  }

  List<Map<String, dynamic>> _normalizeEnvolventeFeatures(
    List<Map<String, dynamic>> features,
  ) {
    final normalized = <Map<String, dynamic>>[];
    final totalPointLoad = _estimateEnvolventePointLoad(features);
    final adaptiveRingLimit = _computeAdaptiveEnvolventeRingLimit(totalPointLoad);

    for (final feature in features) {
      final geometry = _asStringDynamicMap(feature['geometry']);
      if (geometry == null) continue;

      final optimizedGeometry = _optimizeEnvolventeGeometry(
        geometry,
        maxRingPoints: adaptiveRingLimit,
      );
      if (optimizedGeometry == null) continue;

      final geometryType = (optimizedGeometry['type']?.toString() ?? '').toUpperCase();
      if (geometryType != 'POLYGON' && geometryType != 'MULTIPOLYGON') {
        continue;
      }

      final bbox = _computeGeoJsonGeometryBbox(optimizedGeometry);

      final rawProps = feature['properties'];
      final props = rawProps is Map
          ? Map<String, dynamic>.from(rawProps)
          : <String, dynamic>{};

      final normalizedProps = <String, dynamic>{
        ...props,
        '__import_kind': 'envolvente',
        '__envolvente': true,
        'categoria': 'ENVOLVENTE',
        if (bbox != null) '__bbox': bbox,
      };

      normalized.add(
        <String, dynamic>{
          'type': 'Feature',
          'geometry': optimizedGeometry,
          'properties': normalizedProps,
          '__import_kind': 'envolvente',
          '__envolvente': true,
          if (bbox != null) '__bbox': bbox,
        },
      );
    }

    return normalized;
  }

  int _estimateEnvolventePointLoad(List<Map<String, dynamic>> features) {
    var total = 0;
    for (final feature in features) {
      final geometry = _asStringDynamicMap(feature['geometry']);
      final coords = geometry?['coordinates'];
      if (coords is! List) continue;
      total += _countCoordinatePoints(coords);
    }
    return total;
  }

  int _countCoordinatePoints(dynamic node) {
    if (node is List) {
      if (node.length >= 2 && node[0] is num && node[1] is num) {
        return 1;
      }
      var sum = 0;
      for (final child in node) {
        sum += _countCoordinatePoints(child);
      }
      return sum;
    }
    return 0;
  }

  int _computeAdaptiveEnvolventeRingLimit(int totalPointLoad) {
    if (totalPointLoad <= _maxEnvolventeTotalPoints) {
      return _maxEnvolventeRingPoints;
    }

    var maxCap = _maxEnvolventeRingPoints;
    var minCap = _minEnvolventeRingPoints;

    if (totalPointLoad >= _envolventeExtremeThreshold) {
      // Modo extremo para evitar congelamiento en cargas muy densas.
      maxCap = 80;
      minCap = 32;
    } else if (totalPointLoad >= _envolventeUltraThreshold) {
      // Modo ultra-ligero para mantener fluidez de desplazamiento.
      maxCap = 120;
      minCap = 40;
    }

    final ratio = totalPointLoad / _maxEnvolventeTotalPoints;
    final reduced = (maxCap / ratio).floor();
    return reduced.clamp(minCap, maxCap);
  }

  Map<String, dynamic>? _optimizeEnvolventeGeometry(
    Map<String, dynamic> geometry, {
    required int maxRingPoints,
  }) {
    final type = geometry['type']?.toString();
    final coords = geometry['coordinates'];
    if (type == null || coords is! List) return null;

    if (type == 'Polygon') {
      final outerRaw = coords.whereType<List>().isNotEmpty ? coords.whereType<List>().first : null;
      if (outerRaw == null) return null;
      final outer = _simplifyGeoJsonRing(outerRaw, maxPoints: maxRingPoints);
      if (outer.length < 4) return null;
      return {
        ...geometry,
        'type': 'Polygon',
        // Para ENVOLVENTE priorizamos rendimiento: conservar solo anillo exterior.
        'coordinates': [outer],
      };
    }

    if (type == 'MultiPolygon') {
      final polygons = <List<List<dynamic>>>[];
      for (final polygon in coords.whereType<List>()) {
        final ringList = polygon.whereType<List>().toList(growable: false);
        if (ringList.isEmpty) continue;
        final outer = _simplifyGeoJsonRing(ringList.first, maxPoints: maxRingPoints);
        if (outer.length >= 4) {
          // Para ENVOLVENTE priorizamos rendimiento: conservar solo anillo exterior.
          polygons.add([outer]);
        }
      }
      if (polygons.isEmpty) return null;
      return {
        ...geometry,
        'type': 'MultiPolygon',
        'coordinates': polygons,
      };
    }

    return geometry;
  }

  List<dynamic> _simplifyGeoJsonRing(
    List<dynamic> ring, {
    required int maxPoints,
  }) {
    final points = <List<dynamic>>[];
    for (final rawPoint in ring.whereType<List>()) {
      if (rawPoint.length < 2) continue;
      final x = _toDoubleCoord(rawPoint[0]);
      final y = _toDoubleCoord(rawPoint[1]);
      if (x == null || y == null) continue;
      points.add(List<dynamic>.from(rawPoint));
    }

    if (points.length < 4) return points;

    final closed = _coordEquals(points.first, points.last);
    final core = closed ? points.sublist(0, points.length - 1) : points;
    if (core.length <= maxPoints) {
      return closed ? [...core, List<dynamic>.from(core.first)] : core;
    }

    final step = (core.length / maxPoints).ceil();
    final sampled = <List<dynamic>>[];
    for (var i = 0; i < core.length; i += step) {
      sampled.add(core[i]);
    }
    if (sampled.isEmpty || !_coordEquals(sampled.first, core.first)) {
      sampled.insert(0, core.first);
    }
    if (!_coordEquals(sampled.last, core.last)) {
      sampled.add(core.last);
    }

    if (sampled.length < 3) {
      return closed ? [...core, List<dynamic>.from(core.first)] : core;
    }

    return [...sampled, List<dynamic>.from(sampled.first)];
  }

  bool _coordEquals(List<dynamic> a, List<dynamic> b) {
    if (a.length < 2 || b.length < 2) return false;
    final ax = _toDoubleCoord(a[0]);
    final ay = _toDoubleCoord(a[1]);
    final bx = _toDoubleCoord(b[0]);
    final by = _toDoubleCoord(b[1]);
    if (ax == null || ay == null || bx == null || by == null) return false;
    return (ax - bx).abs() < 1e-12 && (ay - by).abs() < 1e-12;
  }

  Map<String, double>? _computeGeoJsonGeometryBbox(Map<String, dynamic> geometry) {
    final coords = geometry['coordinates'];
    if (coords is! List) return null;

    double? minX;
    double? minY;
    double? maxX;
    double? maxY;

    void visit(dynamic node) {
      if (node is List) {
        if (node.length >= 2 && node[0] is num && node[1] is num) {
          final x = (node[0] as num).toDouble();
          final y = (node[1] as num).toDouble();
          minX = minX == null ? x : math.min(minX!, x);
          minY = minY == null ? y : math.min(minY!, y);
          maxX = maxX == null ? x : math.max(maxX!, x);
          maxY = maxY == null ? y : math.max(maxY!, y);
        } else {
          for (final child in node) {
            visit(child);
          }
        }
      }
    }

    visit(coords);
    if (minX == null || minY == null || maxX == null || maxY == null) {
      return null;
    }

    return {
      'minX': minX!,
      'minY': minY!,
      'maxX': maxX!,
      'maxY': maxY!,
    };
  }

  bool _isPksPointImport({
    required String fileName,
    required List<Map<String, dynamic>> features,
  }) {
    if (features.isEmpty) return false;

    final fromName = _normalizeValue(fileName).contains('PKS');
    final fromProps = features.any(_featureMentionsPks);
    if (!fromName && !fromProps) return false;

    var geometries = 0;
    var pointGeometries = 0;
    for (final feature in features) {
      final type = _geometryType(feature);
      if (type == null || type.isEmpty) continue;
      geometries++;
      if (type == 'POINT' || type == 'MULTIPOINT') {
        pointGeometries++;
      }
    }

    if (geometries == 0) return false;
    return pointGeometries == geometries;
  }

  String? _geometryType(Map<String, dynamic> feature) {
    final geometry = _asStringDynamicMap(feature['geometry']);
    final type = geometry?['type']?.toString().trim().toUpperCase();
    if (type == null || type.isEmpty) return null;
    return type;
  }

  bool _featureMentionsPks(Map<String, dynamic> feature) {
    final rawProps = feature['properties'];
    if (rawProps is! Map) return false;
    final props = Map<String, dynamic>.from(rawProps);

    final direct = _pickTextByAliases(props, const [
      'proyecto',
      'linea',
      'origen',
      'tipo',
      'sistema',
      'corredor',
    ]);
    if (direct != null && _normalizeValue(direct).contains('PKS')) {
      return true;
    }

    for (final value in props.values) {
      final text = value?.toString();
      if (text == null) continue;
      if (_normalizeValue(text).contains('PKS')) {
        return true;
      }
    }

    return false;
  }

  List<Map<String, dynamic>> _normalizePksPointFeatures(
    List<Map<String, dynamic>> features,
  ) {
    final normalized = <Map<String, dynamic>>[];

    for (var i = 0; i < features.length; i++) {
      final feature = features[i];
      final geometry = _normalizePksGeometry(feature['geometry']);
      final geometryType = geometry?['type']?.toString().toUpperCase();
      if (geometryType != 'POINT' && geometryType != 'MULTIPOINT') {
        continue;
      }

      final rawProps = feature['properties'];
      final props = rawProps is Map
          ? Map<String, dynamic>.from(rawProps)
          : <String, dynamic>{};

      final label = _pickTextByAliases(props, const [
            'propiedad',
            'etiqueta',
            'label',
            'nombre',
            'name',
            'descripcion',
            'pk',
        'pks',
        'pks_num',
        'pks_numero',
        'numero_pk',
        'numero_pks',
            'id',
            'clave',
          ]);

      final normalizedProps = <String, dynamic>{
        ...props,
        if (label != null && label.isNotEmpty) 'pks_label': label,
      };

      normalized.add(
        <String, dynamic>{
          'type': 'Feature',
          'geometry': geometry,
          'properties': normalizedProps,
        },
      );
    }

    return normalized;
  }

  Map<String, dynamic>? _normalizePksGeometry(dynamic rawGeometry) {
    final geometry = _asStringDynamicMap(rawGeometry);
    if (geometry == null) return null;

    final type = geometry['type']?.toString();
    final coords = geometry['coordinates'];
    if (type == null || coords is! List) return null;

    if (type == 'Point') {
      final point = _normalizePointCoordinate(coords);
      if (point == null) return null;
      return {
        'type': 'Point',
        'coordinates': point,
      };
    }

    if (type == 'MultiPoint') {
      final points = coords
          .whereType<List>()
          .map(_normalizePointCoordinate)
          .whereType<List<double>>()
          .toList(growable: false);
      if (points.isEmpty) return null;
      return {
        'type': 'MultiPoint',
        'coordinates': points,
      };
    }

    return null;
  }

  List<double>? _normalizePointCoordinate(List<dynamic> coord) {
    if (coord.length < 2) return null;
    final x = _toDoubleCoord(coord[0]);
    final y = _toDoubleCoord(coord[1]);
    if (x == null || y == null) return null;
    return [x, y];
  }

  double? _toDoubleCoord(dynamic value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final normalized = text
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(normalized);
  }

  String? _pickTextByAliases(Map<String, dynamic> props, List<String> aliases) {
    final aliasKeys = aliases
        .map(_normalizeKey)
        .toSet();

    for (final entry in props.entries) {
      final key = _normalizeKey(entry.key);
      if (!aliasKeys.contains(key)) continue;
      final value = entry.value?.toString().trim();
      if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
        continue;
      }
      return value;
    }

    return null;
  }

  String _normalizeKey(String raw) {
    return _normalizeValue(raw).replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String _normalizeValue(String raw) {
    const accentMap = {
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'Ñ': 'N',
    };

    var out = raw.toUpperCase().trim();
    accentMap.forEach((k, v) {
      out = out.replaceAll(k, v);
    });
    return out;
  }

  bool _shouldClearPksPointsAfterFileDeletion({
    required List<Map<String, dynamic>> currentPks,
    required List<Map<String, dynamic>> fileFeatures,
  }) {
    if (currentPks.isEmpty || fileFeatures.isEmpty) return false;
    if (identical(currentPks, fileFeatures)) return true;

    if (currentPks.length != fileFeatures.length) return false;
    try {
      return jsonEncode(currentPks.first) == jsonEncode(fileFeatures.first);
    } catch (_) {
      return false;
    }
  }

  /// Normaliza el valor de tipo_propiedad a los valores válidos del sistema
  String _normalizeTipoPropiedad(String? value) {
    if (value == null || value.isEmpty) return 'PRIVADA';
    final upper = value.toUpperCase().trim();
    final compact = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.contains('SOC')) return 'SOCIAL';
    if (compact.contains('DOMINIOPLENO') || (compact.contains('DOMINIO') && compact.contains('PLENO'))) return 'DOMINIO PLENO';
    if (upper.contains('FEDERAL')) return 'FEDERAL';
    if (upper.contains('GUBERNAMENTAL') || upper.contains('GUBERNAM') || upper.contains('GOBIERNO')) return 'GUBERNAMENTAL';
    if (upper.contains('EJIDAL')) return 'EJIDAL';
    if (upper.contains('MIXTO')) return 'MIXTO';
    if (compact.contains('PRIVAD') || compact == 'PRI') return 'PRIVADA';
    return upper.isEmpty ? 'PRIVADA' : upper;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized);
    }
    return null;
  }

  List<Map<String, dynamic>> _erroresSincronizacion() {
    final resultado = _syncResultado;
    if (resultado == null) return const [];

    return resultado.features.where((feature) {
      final props = _asStringDynamicMap(feature['properties']) ?? <String, dynamic>{};
      return props['_syncStatus']?.toString() == 'error' ||
          (props['_syncError']?.toString().trim().isNotEmpty ?? false);
    }).toList(growable: false);
  }

  String _buildErrorReportJson() {
    final resultado = _syncResultado;
    final errores = _erroresSincronizacion();
    final report = <String, dynamic>{
      'archivo': _archivoSeleccionado?.name,
      'generado_en': DateTime.now().toIso8601String(),
      'resumen': {
        'total_features': _totalFeatures,
        'creados': resultado?.creados ?? 0,
        'encontrados': resultado?.encontrados ?? 0,
        'errores': resultado?.errores ?? 0,
        'errores_exportados': errores.length,
      },
      'mensajes_error': resultado?.mensajesError ?? const [],
      'features_con_error': errores,
    };

    return const JsonEncoder.withIndent('  ').convert(report);
  }

  String _csvEscape(dynamic value) {
    final text = value?.toString() ?? '';
    final escaped = text.replaceAll('"', '""');
    if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _buildErrorReportCsv() {
    final rows = <String>[
      'clave_catastral,predio_id,sync_status,sync_error,proyecto,tramo,propietario,tipo_geom',
    ];

    for (final feature in _erroresSincronizacion()) {
      final props = _asStringDynamicMap(feature['properties']) ?? <String, dynamic>{};
      rows.add([
        _csvEscape(props['clave_catastral'] ?? props['_claveCatastral']),
        _csvEscape(props['predio_id'] ?? props['_predioId']),
        _csvEscape(props['_syncStatus']),
        _csvEscape(props['_syncError']),
        _csvEscape(props['_proyecto'] ?? props['proyecto']),
        _csvEscape(props['_tramo'] ?? props['tramo']),
        _csvEscape(props['_propietarioNombre'] ?? props['propietario']),
        _csvEscape(_asStringDynamicMap(feature['geometry'])?['type']),
      ].join(','));
    }

    return rows.join('\n');
  }

  Future<void> _exportarReporteErrores({required bool asCsv}) async {
    final resultado = _syncResultado;
    if (resultado == null) return;

    final contenido = asCsv ? _buildErrorReportCsv() : _buildErrorReportJson();
    final extension = asCsv ? 'csv' : 'json';
    final mimeType = asCsv ? 'text/csv' : 'application/json';
    final nombreBase = (_archivoSeleccionado?.name ?? 'reporte_importacion')
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    final fileName = '${nombreBase}_errores_importacion.$extension';

    try {
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(contenido)),
        mimeType: mimeType,
        name: fileName,
      );

      await Share.shareXFiles(
        [file],
        text: 'Reporte de errores de importación GeoJSON',
        subject: fileName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte de errores generado.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo exportar el reporte: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _descargarArchivoImportado(
    ImportedFile file, {
    required String formato,
  }) async {
    try {
      final predios = await ref.read(prediosListProvider.future);
      final payload = await buildArchiveExportPayload(
        file: file,
        currentPredios: predios,
        formato: formato,
        fallbackProject: ref.read(gestionProyectoProvider),
      );

      await downloadBytes(
        payload.bytes,
        fileName: payload.fileName,
        mimeType: payload.mimeType,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Descarga generada: ${payload.fileName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo descargar el archivo: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progresoImportacion = ref.watch(importacionProgresoProvider);
    final isBusy = _loading || _sincronizando;

    return AppScaffold(
      currentIndex: 2,
      title: 'Carga de Archivos',
      child: Stack(
        children: [
          AbsorbPointer(
            absorbing: isBusy,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Importa archivos GeoJSON y XLSX para vincular polígonos y propiedades.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Zona de carga
            GestureDetector(
              onTap: _loading ? null : _seleccionarArchivo,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: _archivoSeleccionado != null
                      ? AppColors.secondary.withValues(alpha: 0.05)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _archivoSeleccionado != null
                        ? AppColors.secondary
                        : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _archivoSeleccionado != null
                          ? Icons.check_circle
                          : Icons.upload_file,
                      size: 56,
                      color: _archivoSeleccionado != null
                          ? AppColors.secondary
                          : AppColors.textLight,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _archivoSeleccionado != null
                          ? _archivoSeleccionado!.name
                          : 'Seleccionar archivo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _archivoSeleccionado != null
                            ? AppColors.secondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _archivoSeleccionado != null
                          ? 'Toca para cambiar el archivo'
                            : 'Formatos: .geojson  .json  .xlsx  .xlsl · Máximo 2 MB',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                    ),
                    if (_archivoSeleccionado != null && _tipoArchivoImportacion != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _buildSurveySummaryLabel(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if ((_syncResultado?.errores ?? 0) > 0 ||
                (_syncResultado?.mensajesError.isNotEmpty ?? false)) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _exportarReporteErrores(asCsv: false),
                    icon: const Icon(Icons.data_object_outlined, size: 18),
                    label: const Text('Exportar errores JSON'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportarReporteErrores(asCsv: true),
                    icon: const Icon(Icons.table_view_outlined, size: 18),
                    label: const Text('Exportar errores CSV'),
                  ),
                ],
              ),
            ],

            // Vista previa
            if (_preview.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Vista previa (primeros ${_preview.length} registros)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: _preview.asMap().entries.map((e) {
                    final item = e.value;
                    return Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              (item['tipo_geom'] == 'Polygon' ||
                                      item['tipo_geom'] == 'MultiPolygon')
                                  ? Icons.crop_square_outlined
                                  : Icons.location_on_outlined,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            item['clave'].toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          isThreeLine: item['proyecto'] != null,
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item['proyecto'] != null)
                                Text(
                                  'Proyecto: ${item['proyecto']}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.info),
                                ),
                              Text(
                                [
                                  if (item['tramo'] != null)
                                    'Tramo: ${item['tramo']}',
                                  if (item['propietario'] != null)
                                    item['propietario'].toString(),
                                  '${item['superficie']} m²'  
                                      '${item['tipo_geom'] != null ? '  ·  ${item['tipo_geom']}' : ''}',
                                ].join('  ·  '),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (e.key < _preview.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],

            if (_xlsxParseResult != null) ...[
              const SizedBox(height: 24),
              Text(
                'Vista previa XLSX (primeros ${_xlsxParseResult!.preview.length} registros)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: _xlsxParseResult!.preview.asMap().entries.map((entry) {
                    final item = entry.value;
                    final tabla = item['tabla']?.toString() ?? 'desconocida';
                    final hoja = item['hoja']?.toString() ?? '-';
                    final clave = item['clave_catastral']?.toString();
                    final propietario = item['nombre_completo']?.toString() ??
                        item['propietario_nombre']?.toString() ??
                        item['nombre']?.toString();

                    return Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            tabla == 'predios'
                                ? Icons.table_chart_outlined
                                : Icons.person_outline,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            tabla == 'predios'
                                ? (clave ?? 'Sin clave')
                                : (propietario ?? 'Sin nombre'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'Hoja: $hoja  ·  Tabla detectada: $tabla',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (entry.key < _xlsxParseResult!.preview.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],

            // ── Campos de Gestión detectados ─────────────────────────────
            if (_camposDetectados.isNotEmpty) ...[              
              const SizedBox(height: 16),
              Text(
                'Campos de Gestión detectados',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in {
                    'clave': 'Clave',
                    'proyecto': 'Proyecto',
                    'tramo': 'Tramo',
                    'propietario': 'Propietario',
                    'superficie': 'Superficie',
                    'km_inicio': 'KM inicio',
                    'km_fin': 'KM fin',
                  }.entries)
                    Builder(builder: (context) {
                      final count = _camposDetectados[entry.key] ?? 0;
                      final all  = count == _totalFeatures && count > 0;
                      final part = count > 0 && count < _totalFeatures;
                      final color = all
                          ? AppColors.secondary
                          : part
                              ? Colors.orange
                              : AppColors.textLight;
                      final icon = all
                          ? Icons.check_circle_outline
                          : part
                              ? Icons.warning_amber_outlined
                              : Icons.remove_circle_outline;
                      return Chip(
                        avatar: Icon(icon, size: 14, color: color),
                        label: Text(
                          count > 0
                              ? '${entry.value} ($count/$_totalFeatures)'
                              : entry.value,
                          style: TextStyle(fontSize: 11, color: color),
                        ),
                        backgroundColor: color.withValues(alpha: 0.08),
                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      );
                    }),
                ],
              ),
            ],

            const SizedBox(height: 28),
            if (_archivoSeleccionado != null &&
                (_preview.isNotEmpty || _xlsxParseResult != null)) ...[
              // ── Acción única de guardado ───────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guardar e inyectar datos',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: (_sincronizando)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.table_chart_outlined, size: 18),
                        label: Text(
                          _sincronizando
                              ? 'Guardando…'
                              : ((_tipoArchivoImportacion == 'geojson' &&
                                          (_contenidoGeoJsonImportacion == 'envolvente' ||
                                              _contenidoGeoJsonImportacion == 'pks'))
                                      ? 'Guardar y ver en Mapa'
                                      : (_xlsxParseResult != null
                                  ? 'Inyectar XLSX y abrir Gestión'
                                  : 'Guardar e ir a Gestión')),
                          style: const TextStyle(fontSize: 13),
                        ),
                        onPressed: (_loading || _sincronizando)
                            ? null
                            : (_xlsxParseResult != null
                                ? _inyectarXlsxEnTablas
                                : () => _guardarYVerEnMapa(
                                      forcedGeoJsonContent:
                                          _tipoArchivoImportacion == 'geojson'
                                              ? _contenidoGeoJsonImportacion
                                              : null,
                                    )),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 12, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Para GeoJSON detecta proyecto/tramo/propietario. '
                            'Para XLSX detecta la tabla por encabezados y realiza upsert '
                            'del contenido similar, sin modificar tus encabezados existentes.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textLight),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // ── Tabla de archivos importados ────────────────────
            const SizedBox(height: 40),
            Consumer(
              builder: (context, ref, _) {
                final importedFiles = ref.watch(cargaProvider);

                if (importedFiles.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, color: AppColors.textLight, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'No hay archivos importados',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Archivos importados (${importedFiles.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: (_eliminandoTodos || _eliminandoFileId != null)
                              ? null
                              : () => showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Eliminar todos'),
                                      content: const Text(
                                        '¿Eliminar todos los archivos importados? Se borrarán también de la base de datos.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _eliminarTodos(importedFiles);
                                          },
                                          child: const Text('Eliminar todos',
                                              style: TextStyle(color: AppColors.danger)),
                                        ),
                                      ],
                                    ),
                                  ),
                          icon: _eliminandoTodos
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.delete_sweep_outlined, size: 16, color: AppColors.danger),
                          label: Text(
                            _eliminandoTodos ? 'Eliminando...' : 'Eliminar todos',
                            style: const TextStyle(fontSize: 12, color: AppColors.danger),
                          ),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: importedFiles.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (_, idx) =>
                            _buildArchivoTile(importedFiles[idx]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
    if (isBusy)
      Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_upload_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _sincronizando
                        ? 'Guardando predios...'
                        : 'Procesando archivo...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final progreso = progresoImportacion;
                    final porcentaje = progreso.porcentaje;
                    final porcentajeInt = (porcentaje * 100).round();
                    return Column(
                      children: [
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            value: porcentaje > 0 ? porcentaje : null,
                            backgroundColor: const Color(0xFFE0E0E0),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$porcentajeInt%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${progreso.procesados} / ${progreso.total}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
  ],
),
    );
  }

  // ── Tile de archivo en la lista ──────────────────────────

  Widget _buildArchivoTile(ImportedFile file) {
    final statusColor = file.guardadoEnBD ? AppColors.secondary : AppColors.textLight;
    final statusIcon = file.guardadoEnBD ? Icons.cloud_done_outlined : Icons.cloud_off_outlined;
    final statusLabel = file.guardadoEnBD ? 'Guardado en BD' : 'Solo en memoria';

    final busy = _loading || _sincronizando;
    final eliminandoEste = _eliminandoFileId == file.id;
    return Stack(
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.insert_drive_file_outlined, color: statusColor, size: 18),
          ),
          title: Text(
            file.name.length > 40 ? '${file.name.substring(0, 37)}…' : file.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, size: 11, color: statusColor),
                  const SizedBox(width: 3),
                  Text(statusLabel,
                      style: TextStyle(fontSize: 11, color: statusColor)),
                  if (file.sincronizado) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.info.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${file.encontrados} exist. / ${file.creados} nuevos'
                        '${file.errores > 0 ? " / ${file.errores} err" : ""}',
                        style:
                            TextStyle(fontSize: 10, color: AppColors.info.withOpacity(0.8)),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${file.featureCount} features · ${file.formattedDate}'
                '${file.createdByEmail != null && _isAdminUser() ? " · ${file.createdByEmail}" : ""}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                tooltip: 'Descargar',
                icon: const Icon(Icons.download_outlined, size: 18),
                onSelected: (value) => _descargarArchivoImportado(
                  file,
                  formato: value,
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'geojson',
                    child: Text('Descargar GeoJSON'),
                  ),
                  PopupMenuItem(
                    value: 'xlsx',
                    child: Text('Descargar XLSX'),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              Tooltip(
                message: 'Ver en mapa',
                child: IconButton(
                  icon: const Icon(Icons.map_outlined, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _verEnMapaDesdeTabla(file.id),
                ),
              ),
              Tooltip(
                message: eliminandoEste ? 'Eliminando...' : 'Eliminar',
                child: IconButton(
                  icon: eliminandoEste
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.danger,
                          ),
                        )
                      : const Icon(Icons.delete_outline, size: 18,
                          color: AppColors.danger),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: (_eliminandoFileId != null || _eliminandoTodos)
                      ? null
                      : () => showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Eliminar archivo'),
                              content: Text(
                                '¿Eliminar "${file.name}"?'
                                '${file.guardadoEnBD ? '\nSe borrará también de la base de datos.' : ''}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _eliminarArchivo(file);
                                  },
                                  child: const Text('Eliminar',
                                      style: TextStyle(color: AppColors.danger)),
                                ),
                              ],
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
        if (busy)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _sincronizando ? 'Guardando predios...' : 'Procesando archivo...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          backgroundColor: const Color(0xFFE0E0E0),
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _sincronizando
                            ? 'Esto puede tomar unos segundos'
                            : 'Por favor espera...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _buildSurveySummaryLabel() {
    final tipo = _tipoArchivoImportacion;
    if (tipo == 'xlsx') {
      return 'Tipo seleccionado: XLSX';
    }
    final contenido = _contenidoGeoJsonImportacion;
    final contenidoLabel = switch (contenido) {
      'envolvente' => 'Envolvente',
      'pks' => 'PKs',
      _ => 'Predios',
    };
    return 'Tipo seleccionado: GeoJson · Contenido: $contenidoLabel';
  }
}

class _ImportSurveyResult {
  final String tipoArchivo;
  final String? contenidoGeoJson;

  const _ImportSurveyResult({
    required this.tipoArchivo,
    this.contenidoGeoJson,
  });
}
