import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../estructura/models/proyecto_item.dart';
import '../../estructura/providers/proyectos_provider.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../../mapa/utils/geometry_parsing.dart';
import '../../predios/models/predio.dart';
import '../../predios/providers/predios_provider.dart';
import '../models/composicion.dart';
import '../models/elemento_composicion.dart';
import '../models/hoja.dart';
import '../providers/composiciones_provider.dart';
import '../services/composicion_export_service.dart';
import '../utils/color_hex.dart';
import 'widgets/capas_panel.dart';
import 'widgets/elemento_box.dart';
import 'widgets/herramienta_hoja_dialog.dart';
import 'widgets/panel_propiedades_escala.dart';
import 'widgets/panel_propiedades_forma.dart';
import 'widgets/panel_propiedades_grafica.dart';
import 'widgets/panel_propiedades_mapa.dart';
import 'widgets/panel_propiedades_norte.dart';
import 'widgets/panel_propiedades_simbologia.dart';
import 'widgets/panel_propiedades_texto.dart';
import 'widgets/shape_painter.dart';

/// Editor de una composición: lienzo con una o más hojas, herramientas de
/// figuras/texto/hoja, panel de capas y guardado a Firestore. Ver el plan
/// de "Composiciones" (fase 1) para el alcance completo.
class ComposicionEditorScreen extends ConsumerStatefulWidget {
  const ComposicionEditorScreen({super.key, this.id, this.proyectoInicial});

  /// Id de una composición existente a abrir. Mutuamente excluyente con
  /// [proyectoInicial] (nueva composición).
  final String? id;
  final String? proyectoInicial;

  @override
  ConsumerState<ComposicionEditorScreen> createState() =>
      _ComposicionEditorScreenState();
}

class _ComposicionEditorScreenState
    extends ConsumerState<ComposicionEditorScreen> {
  Composicion? _composicion;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  int _hojaActivaIndex = 0;
  String? _elementoSeleccionadoId;
  int _contadorInsertados = 0;
  bool _exportando = false;
  double _zoomNivel = 1.0;
  final _exportService = ComposicionExportService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _inicializar());
  }

  Future<void> _inicializar() async {
    final repo = ref.read(composicionesRepositoryProvider);
    if (widget.id != null) {
      final composicion = await repo.obtener(widget.id!);
      if (!mounted) return;
      if (composicion == null) {
        setState(() {
          _error = 'Composición no encontrada.';
          _cargando = false;
        });
        return;
      }
      setState(() {
        _composicion = composicion;
        _cargando = false;
      });
      return;
    }

    final user = ref.read(currentUserProvider);
    final nuevoId = await repo.crear(
      nombre: 'Composición sin título',
      proyecto: widget.proyectoInicial ?? '',
      createdByUid: user?.uid,
      createdByEmail: user?.email,
    );
    if (!mounted) return;
    context.go('/composiciones/$nuevoId');
  }

  /// Predios del proyecto de esta composición, para el elemento de tipo
  /// mapa. `prediosMapaProvider` trae todos los proyectos a los que el
  /// usuario tiene acceso; se filtra localmente por `_composicion!.proyecto`
  /// con el mismo criterio (campo directo + prefijo de clave catastral
  /// como respaldo) que ya usan `balance_screen.dart`/`tabla_screen.dart`.
  /// Recibe la lista completa ya resuelta (por `ref.watch` en `build()` o
  /// `ref.read` en las acciones de exportación) porque `ref.watch` no se
  /// puede llamar fuera de `build()`.
  List<Predio> _filtrarPrediosDelProyecto(List<Predio> todos) {
    final proyecto = _composicion?.proyecto.trim().toUpperCase();
    if (proyecto == null || proyecto.isEmpty) {
      return todos
          .where((predio) => predio.geometry != null)
          .toList(growable: false);
    }
    final filtrados = todos
        .where((p) => _predioPerteneceAProyecto(p, proyecto))
        .toList(growable: false);
    if (filtrados.isNotEmpty) return filtrados;

    // Los GeoJSON importados pueden no traer un código de proyecto. En ese
    // caso se conservan sus geometrías para que el mapa de composición
    // coincida con la vista principal de Mapa.
    return todos
        .where((predio) => predio.geometry != null)
        .toList(growable: false);
  }

  bool _predioPerteneceAProyecto(Predio predio, String proyecto) {
    final directo = predio.proyecto?.trim().toUpperCase();
    if (directo != null && directo.isNotEmpty) {
      if (directo == proyecto) return true;
      if (directo == 'TQM' && proyecto == 'TMQ') return true;
      return false;
    }
    final compact = predio.claveCatastral.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    switch (proyecto) {
      case 'TQI':
        return compact.startsWith('TQI') || compact.startsWith('QI');
      case 'TSNL':
        return compact.startsWith('TSNL') ||
            compact.startsWith('SNL') ||
            compact.startsWith('SL');
      case 'TAP':
        return compact.startsWith('TAP') || compact.startsWith('AP');
      case 'TMQ':
        return compact.startsWith('TMQ') ||
            compact.startsWith('TQM') ||
            compact.startsWith('QM');
      default:
        return false;
    }
  }

  List<Predio> _prediosParaElementoMapa(
    ElementoComposicion elemento,
    List<Predio> todos,
  ) {
    final proyectoMapa = elemento.mapaProyecto?.trim().toUpperCase();
    if (proyectoMapa == null || proyectoMapa.isEmpty) {
      return _filtrarPrediosDelProyecto(todos);
    }
    final filtrados = todos
        .where((predio) => _predioPerteneceAProyecto(predio, proyectoMapa))
        .toList(growable: false);
    if (filtrados.isNotEmpty) return filtrados;
    return todos
        .where((predio) => predio.geometry != null)
        .toList(growable: false);
  }

  /// El `ProyectoItem` (Estructura > Proyectos) que corresponde al
  /// proyecto de esta composición, solo necesario para el elemento de
  /// tipo gráfica "Diagrama por cadenamiento" (mismo criterio de
  /// emparejamiento por nombre que usa `balance_screen.dart`).
  ProyectoItem? _proyectoItemDe(List<ProyectoItem> proyectosItems) {
    final proyecto = _composicion?.proyecto.trim().toUpperCase();
    if (proyecto == null || proyecto.isEmpty) return null;
    for (final p in proyectosItems) {
      if (p.nombre.trim().toUpperCase() == proyecto) return p;
    }
    return null;
  }

  Hoja get _hojaActiva => _composicion!.hojas[_hojaActivaIndex];

  ElementoComposicion? get _elementoSeleccionado {
    final id = _elementoSeleccionadoId;
    if (id == null) return null;
    for (final e in _hojaActiva.elementos) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _actualizarHoja(Hoja Function(Hoja hoja) actualizar) {
    setState(() {
      final hojas = List<Hoja>.from(_composicion!.hojas);
      hojas[_hojaActivaIndex] = actualizar(hojas[_hojaActivaIndex]);
      _composicion = _composicion!.copyWith(hojas: hojas);
    });
  }

  void _actualizarElemento(
    String id,
    ElementoComposicion Function(ElementoComposicion) actualizar,
  ) {
    _actualizarHoja((hoja) {
      final elementos = hoja.elementos
          .map((e) => e.id == id ? actualizar(e) : e)
          .toList();
      return hoja.copyWith(elementos: elementos);
    });
  }

  void _agregarElemento(
    ElementoComposicion Function(double x, double y) crear,
  ) {
    _contadorInsertados++;
    final offset = (_contadorInsertados % 8) * 10.0;
    final elemento = crear(20 + offset, 20 + offset);
    _actualizarHoja(
      (hoja) => hoja.copyWith(elementos: [...hoja.elementos, elemento]),
    );
    setState(() => _elementoSeleccionadoId = elemento.id);
  }

  void _eliminarElemento(String id) {
    _actualizarHoja(
      (hoja) => hoja.copyWith(
        elementos: hoja.elementos.where((e) => e.id != id).toList(),
      ),
    );
    if (_elementoSeleccionadoId == id) {
      setState(() => _elementoSeleccionadoId = null);
    }
  }

  void _reordenarElemento(int oldZ, int newZ) {
    _actualizarHoja((hoja) {
      final elementos = List<ElementoComposicion>.from(hoja.elementos);
      final elemento = elementos.removeAt(oldZ);
      elementos.insert(newZ, elemento);
      return hoja.copyWith(elementos: elementos);
    });
  }

  void _agregarHoja() {
    setState(() {
      final hojas = List<Hoja>.from(_composicion!.hojas)
        ..add(Hoja.nueva(nombre: 'Hoja ${_composicion!.hojas.length + 1}'));
      _composicion = _composicion!.copyWith(hojas: hojas);
      _hojaActivaIndex = hojas.length - 1;
      _elementoSeleccionadoId = null;
    });
  }

  void _eliminarHojaActiva() {
    if (_composicion!.hojas.length <= 1) return;
    setState(() {
      final hojas = List<Hoja>.from(_composicion!.hojas)
        ..removeAt(_hojaActivaIndex);
      _composicion = _composicion!.copyWith(hojas: hojas);
      _hojaActivaIndex = _hojaActivaIndex.clamp(0, hojas.length - 1);
      _elementoSeleccionadoId = null;
    });
  }

  Future<void> _guardar() async {
    if (_composicion == null || _guardando) return;
    setState(() => _guardando = true);
    try {
      await ref.read(composicionesRepositoryProvider).guardar(_composicion!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Composición guardada.'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Centro por defecto para un mapa nuevo: el primer predio con
  /// geometría del proyecto, o el centro por defecto de la pantalla de
  /// Mapa (`_defaultCenter` en `mapa_screen.dart`, Querétaro) si el
  /// proyecto todavía no tiene predios geolocalizados.
  (double, double) _centroPorDefecto(List<Predio> predios) {
    for (final p in predios) {
      final rings = extractRingsFromGeometry(p.geometry);
      if (rings.isNotEmpty && rings.first.isNotEmpty) {
        final punto = rings.first.first;
        return (punto.latitude, punto.longitude);
      }
    }
    return (20.72, -100.35);
  }

  /// Selecciona una imagen local, la comprime/redimensiona a JPEG (no hay
  /// Storage habilitado en este proyecto -ver `storage.rules`-, así que
  /// se embebe como base64 directo en el documento de la composición) y
  /// la agrega como nuevo elemento.
  Future<void> _importarImagen() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final decodificada = img.decodeImage(bytes);
    if (decodificada == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo leer la imagen.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    const dimensionMaxPx = 1600;
    var redimensionada = decodificada;
    if (decodificada.width > dimensionMaxPx ||
        decodificada.height > dimensionMaxPx) {
      redimensionada = decodificada.width >= decodificada.height
          ? img.copyResize(decodificada, width: dimensionMaxPx)
          : img.copyResize(decodificada, height: dimensionMaxPx);
    }
    final jpgBytes = img.encodeJpg(redimensionada, quality: 80);
    final base64Str = base64Encode(jpgBytes);

    if (base64Str.length > 700000 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La imagen es pesada: si agregas varias podrías acercarte al límite de tamaño de Firestore (1 MB por composición).',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
    }

    const anchoMaxMm = 120.0;
    final aspecto = redimensionada.height / redimensionada.width;
    _agregarElemento(
      (x, y) => ElementoComposicion.imagen(
        base64: base64Str,
        x: x,
        y: y,
        width: anchoMaxMm,
        height: anchoMaxMm * aspecto,
      ),
    );
  }

  List<Predio> _prediosParaExportar() => _filtrarPrediosDelProyecto(
    ref.read(prediosMapaProvider).valueOrNull ?? const [],
  );

  ProyectoItem? _proyectoItemParaExportar() => _proyectoItemDe(
    ref.read(proyectosProvider).valueOrNull ?? const <ProyectoItem>[],
  );

  Future<void> _exportarPng() => _ejecutarExportacion(() async {
    final bytes = await _exportService.capturarHojaPng(
      context,
      _hojaActiva,
      predios: _prediosParaExportar(),
      proyectoItem: _proyectoItemParaExportar(),
    );
    await _exportService.descargar(
      bytes,
      fileName: '${_composicion!.nombre}_${_hojaActiva.nombre}.png',
      mimeType: 'image/png',
    );
  });

  Future<void> _exportarJpg() => _ejecutarExportacion(() async {
    final bytes = await _exportService.capturarHojaJpg(
      context,
      _hojaActiva,
      predios: _prediosParaExportar(),
      proyectoItem: _proyectoItemParaExportar(),
    );
    await _exportService.descargar(
      bytes,
      fileName: '${_composicion!.nombre}_${_hojaActiva.nombre}.jpg',
      mimeType: 'image/jpeg',
    );
  });

  Future<void> _exportarPdf() => _ejecutarExportacion(() async {
    final bytes = await _exportService.exportarPdf(
      context,
      _composicion!,
      predios: _prediosParaExportar(),
      proyectoItem: _proyectoItemParaExportar(),
    );
    await _exportService.descargar(
      bytes,
      fileName: '${_composicion!.nombre}.pdf',
      mimeType: 'application/pdf',
    );
  });

  Future<void> _exportarPptx() => _ejecutarExportacion(() async {
    final bytes = await _exportService.exportarPptx(
      context,
      _composicion!,
      predios: _prediosParaExportar(),
      proyectoItem: _proyectoItemParaExportar(),
    );
    await _exportService.descargar(
      bytes,
      fileName: '${_composicion!.nombre}.pptx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    );
  });

  Future<void> _ejecutarExportacion(Future<void> Function() accion) async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      await accion();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exportado correctamente.'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo exportar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AppScaffold(
        currentIndex: 7,
        title: 'Composiciones',
        child: Center(child: Text(_error!)),
      );
    }

    if (_cargando || _composicion == null) {
      return const AppScaffold(
        currentIndex: 7,
        title: 'Composiciones',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final composicion = _composicion!;
    final todosLosPredios =
        ref.watch(prediosMapaProvider).valueOrNull ?? const <Predio>[];
    final importedFeatures = ref.watch(importedFeaturesProvider);
    final proyectoItem = _proyectoItemDe(
      ref.watch(proyectosProvider).valueOrNull ?? const <ProyectoItem>[],
    );

    return AppScaffold(
      currentIndex: 7,
      title: composicion.nombre,
      actions: const [],
      child: Column(
        children: [
          _buildBarraAccionesSuperior(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBarraLateral(todosLosPredios),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildLienzo(
                          todosLosPredios,
                          proyectoItem,
                          importedFeatures,
                        ),
                      ),
                      const Divider(height: 1),
                      _buildBarraHojas(),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                _buildPanelLateralDerecho(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraAccionesSuperior() {
    return Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _herramientaBoton(
                    icon: Icons.description_outlined,
                    tooltip: 'Hoja',
                    onTap: () async {
                      final resultado = await mostrarHerramientaHojaDialog(
                        context,
                        hoja: _hojaActiva,
                      );
                      if (resultado == null) return;
                      _actualizarHoja(
                        (hoja) => hoja.copyWith(
                          tamano: resultado.tamano,
                          horizontal: resultado.horizontal,
                          margenMm: resultado.margenMm,
                          clearColorFondo: resultado.colorFondoHex == null,
                          colorFondoHex: resultado.colorFondoHex,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  _herramientaBoton(
                    icon: Icons.note_add_outlined,
                    tooltip: 'Mapa',
                    onTap: () {
                      final (lat, lng) = _centroPorDefecto(
                        ref.read(prediosMapaProvider).valueOrNull ?? const [],
                      );
                      _agregarElemento(
                        (x, y) => ElementoComposicion.mapa(
                          lat: lat,
                          lng: lng,
                          zoom: 14,
                          proyecto: _composicion!.proyecto,
                          x: x,
                          y: y,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  _herramientaFigurasBoton(),
                  const SizedBox(width: 6),
                  _herramientaBoton(
                    icon: Icons.text_fields,
                    tooltip: 'Texto',
                    onTap: () => _agregarElemento(
                      (x, y) => ElementoComposicion.texto(x: x, y: y),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _herramientaNorteBoton(),
                  const SizedBox(width: 6),
                  _herramientaEscalaBoton(),
                  const SizedBox(width: 6),
                  _herramientaSimbologiaBoton(),
                  const SizedBox(width: 6),
                  _herramientaGraficaBoton(),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _accionSuperior(
                icon: Icons.image_outlined,
                tooltip: 'Importar imagen',
                onTap: _importarImagen,
              ),
              const SizedBox(width: 8),
              _accionSuperior(
                icon: _exportando
                    ? Icons.hourglass_top_outlined
                    : Icons.print_outlined,
                tooltip: 'Exportar',
                enabled: !_exportando,
                onTap: _exportando
                    ? null
                    : () {
                        final actions = [
                          ('png', 'Exportar PNG', _exportarPng),
                          ('jpg', 'Exportar JPG', _exportarJpg),
                          ('pdf', 'Exportar PDF', _exportarPdf),
                          ('pptx', 'Exportar PPTX', _exportarPptx),
                        ];
                        showMenu<String>(
                          context: context,
                          position: const RelativeRect.fromLTRB(
                            1000,
                            120,
                            24,
                            0,
                          ),
                          items: [
                            for (final (value, label, action) in actions)
                              PopupMenuItem<String>(
                                value: value,
                                onTap: () => Future.microtask(action),
                                child: Text(label),
                              ),
                          ],
                        );
                      },
              ),
              const SizedBox(width: 8),
              _accionSuperior(
                icon: Icons.edit_outlined,
                tooltip: 'Renombrar composición',
                onTap: _renombrar,
              ),
              const SizedBox(width: 8),
              _accionSuperior(
                icon: Icons.save_outlined,
                tooltip: _guardando ? 'Guardando...' : 'Guardar',
                enabled: !_guardando,
                onTap: _guardando ? null : _guardar,
                destacado: true,
              ),
              const SizedBox(width: 8),
              _accionSuperior(
                icon: Icons.zoom_out,
                tooltip: 'Reducir zoom',
                enabled: _zoomNivel > 0.5,
                onTap: () => setState(
                  () => _zoomNivel = (_zoomNivel - 0.1).clamp(0.5, 2.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${(_zoomNivel * 100).round()}%',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              _accionSuperior(
                icon: Icons.zoom_in,
                tooltip: 'Aumentar zoom',
                enabled: _zoomNivel < 2.5,
                onTap: () => setState(
                  () => _zoomNivel = (_zoomNivel + 0.1).clamp(0.5, 2.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accionSuperior({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool enabled = true,
    bool destacado = false,
  }) {
    final child = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: destacado ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: enabled ? onTap : null,
        icon: Icon(
          icon,
          size: 18,
          color: destacado ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
    return Tooltip(message: tooltip, child: child);
  }

  Future<void> _renombrar() async {
    final ctrl = TextEditingController(text: _composicion!.nombre);
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar composición'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevoNombre == null || nuevoNombre.isEmpty) return;
    setState(() => _composicion = _composicion!.copyWith(nombre: nuevoNombre));
  }

  Widget _buildBarraLateral(List<Predio> predios) {
    return SizedBox(
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text('Capas', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          Expanded(
            child: CapasPanel(
              elementos: _hojaActiva.elementos,
              seleccionadoId: _elementoSeleccionadoId,
              onSelect: (id) => setState(() => _elementoSeleccionadoId = id),
              onReorder: _reordenarElemento,
              onToggleVisible: (id) => _actualizarElemento(
                id,
                (e) => e.copyWith(visible: !e.visible),
              ),
              onToggleBloqueado: (id) => _actualizarElemento(
                id,
                (e) => e.copyWith(bloqueado: !e.bloqueado),
              ),
              onEliminar: _eliminarElemento,
            ),
          ),
        ],
      ),
    );
  }

  Widget _herramientaBoton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool deshabilitada = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            icon,
            size: 16,
            color: deshabilitada ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  static const _figurasDisponibles = [
    (TipoFigura.rectangulo, 'Rectángulo'),
    (TipoFigura.cuadrado, 'Cuadrado'),
    (TipoFigura.triangulo, 'Triángulo'),
    (TipoFigura.hexagono, 'Hexágono'),
    (TipoFigura.pentagono, 'Pentágono'),
    (TipoFigura.linea, 'Línea continua'),
    (TipoFigura.lineaPunteada, 'Línea punteada'),
  ];

  Widget _herramientaFigurasBoton() {
    return Tooltip(
      message: 'Figuras',
      child: PopupMenuButton<TipoFigura>(
        tooltip: '',
        offset: const Offset(0, 32),
        onSelected: (figura) => _agregarElemento(
          (x, y) => ElementoComposicion.forma(figuraTipo: figura, x: x, y: y),
        ),
        itemBuilder: (context) => [
          PopupMenuItem<TipoFigura>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: _selectorDeFiguras(),
          ),
        ],
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.category_outlined,
            size: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// Ventana con la representación visual de cada figura (en vez de una
  /// lista de texto), para que el usuario elija a partir de cómo se ve.
  /// Cada celda vive dentro de un `PopupMenuItem` con `enabled: false`
  /// (así el `InkWell` que envuelve normalmente cada item no intercepta el
  /// toque) y cierra el menú devolviendo su propio valor con
  /// `Navigator.pop`, el mismo mecanismo que usa `PopupMenuItem` por
  /// dentro.
  Widget _selectorDeFiguras() {
    return SizedBox(
      width: 216,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (tipo, nombre) in _figurasDisponibles)
              Tooltip(
                message: nombre,
                child: Builder(
                  builder: (context) => InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.of(context).pop(tipo),
                    child: Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CustomPaint(
                        size: const Size.square(double.infinity),
                        painter: ShapePainter(
                          figuraTipo: tipo,
                          colorTrazo: AppColors.primary,
                          grosorTrazo: 2,
                          colorRelleno:
                              tipo == TipoFigura.linea ||
                                  tipo == TipoFigura.lineaPunteada
                              ? null
                              : AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _herramientaNorteBoton() {
    return _herramientaBoton(
      icon: Icons.explore_outlined,
      tooltip: 'Norte',
      onTap: () =>
          _agregarElemento((x, y) => ElementoComposicion.norte(x: x, y: y)),
    );
  }

  Widget _herramientaEscalaBoton() {
    return _herramientaBoton(
      icon: Icons.straighten_outlined,
      tooltip: 'Escala gráfica',
      onTap: () {
        final mapasEnHoja = _hojaActiva.elementos.where(
          (e) => e.tipo == TipoElemento.mapa,
        );
        final mapaId = mapasEnHoja.isEmpty ? null : mapasEnHoja.first.id;
        _agregarElemento(
          (x, y) => ElementoComposicion.escala(x: x, y: y, mapaId: mapaId),
        );
      },
    );
  }

  Widget _herramientaSimbologiaBoton() {
    return Tooltip(
      message: 'Simbología',
      child: PopupMenuButton<TipoSimbologia>(
        tooltip: '',
        offset: const Offset(0, 32),
        onSelected: (tipo) => _agregarElemento(
          (x, y) => ElementoComposicion.simbologia(tipo: tipo, x: x, y: y),
        ),
        itemBuilder: (context) => const [
          PopupMenuItem(value: TipoSimbologia.estatus, child: Text('Estatus')),
          PopupMenuItem(
            value: TipoSimbologia.rangoEstatus,
            child: Text('Rango de estatus'),
          ),
          PopupMenuItem(
            value: TipoSimbologia.tipoPropiedad,
            child: Text('Tipo de propiedad'),
          ),
        ],
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.palette_outlined,
            size: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _herramientaGraficaBoton() {
    return Tooltip(
      message: 'Gráfica (Balance)',
      child: PopupMenuButton<TipoGrafica>(
        tooltip: '',
        offset: const Offset(0, 32),
        onSelected: (tipo) => _agregarElemento(
          (x, y) => ElementoComposicion.grafica(
            tipo: tipo,
            proyecto: _composicion!.proyecto,
            x: x,
            y: y,
          ),
        ),
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: TipoGrafica.kpiPanel,
            child: Text('KPIs (avance de proyecto)'),
          ),
          PopupMenuItem(
            value: TipoGrafica.avanceDdv,
            child: Text('Avance DDV'),
          ),
          PopupMenuItem(
            value: TipoGrafica.rangoEstatus,
            child: Text('Rango de estatus'),
          ),
          PopupMenuItem(
            value: TipoGrafica.tipoLiberacion,
            child: Text('Tipo de liberación'),
          ),
          PopupMenuItem(
            value: TipoGrafica.tipoPropiedad,
            child: Text('Avance por tipo de propiedad'),
          ),
          PopupMenuItem(
            value: TipoGrafica.segmentoTramoFrente,
            child: Text('Avance por segmento/tramo/frente'),
          ),
          PopupMenuItem(
            value: TipoGrafica.cadenamiento,
            child: Text('Diagrama por cadenamiento'),
          ),
          PopupMenuItem(
            value: TipoGrafica.avanceMensual,
            child: Text('Avance mensual'),
          ),
          PopupMenuItem(
            value: TipoGrafica.avanceSemanal,
            child: Text('Avance semanal'),
          ),
        ],
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.bar_chart_outlined,
            size: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBarraHojas() {
    final hojas = _composicion!.hojas;
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hojas.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final activa = index == _hojaActivaIndex;
                return ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  label: Text(
                    hojas[index].nombre,
                    style: const TextStyle(fontSize: 10),
                  ),
                  selected: activa,
                  onSelected: (_) => setState(() {
                    _hojaActivaIndex = index;
                    _elementoSeleccionadoId = null;
                  }),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Insertar otra hoja',
            icon: const Icon(Icons.add_box_outlined, size: 18),
            onPressed: _agregarHoja,
          ),
          IconButton(
            tooltip: 'Eliminar hoja activa',
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: hojas.length > 1 ? _eliminarHojaActiva : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLienzo(
    List<Predio> todosLosPredios,
    ProyectoItem? proyectoItem,
    List<Map<String, dynamic>> importedFeatures,
  ) {
    final hoja = _hojaActiva;
    final (anchoMm, altoMm) = hoja.dimensionesMm;
    return Container(
      color: const Color(0xFFE9ECF2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const topRulerHeight = 24.0;
          const leftRulerWidth = 24.0;
          final scaleAncho = (constraints.maxWidth - leftRulerWidth) / anchoMm;
          final scaleAlto = (constraints.maxHeight - topRulerHeight) / altoMm;
          final scaleBase =
              (scaleAncho < scaleAlto ? scaleAncho : scaleAlto) * 0.94;
          final scale = scaleBase * _zoomNivel;
          final wPx = anchoMm * scale;
          final hPx = altoMm * scale;
          final areaUtilAncho = constraints.maxWidth - leftRulerWidth;
          final areaUtilAlto = constraints.maxHeight - topRulerHeight;
          final offsetHojaX =
              (areaUtilAncho - wPx).clamp(0.0, double.infinity) / 2;
          final offsetHojaY =
              (areaUtilAlto - hPx).clamp(0.0, double.infinity) / 2;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 0,
                left: leftRulerWidth + offsetHojaX,
                width: wPx,
                height: topRulerHeight,
                child: ColoredBox(
                  color: const Color(0xFFF5F5F5),
                  child: CustomPaint(
                    painter: _ReglaHojaPainter(
                      longitudMm: anchoMm,
                      scale: scale,
                      origenPx: 0,
                      horizontal: true,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                width: leftRulerWidth,
                child: ColoredBox(
                  color: const Color(0xFFF5F5F5),
                  child: CustomPaint(
                    painter: _ReglaHojaPainter(
                      longitudMm: constraints.maxHeight / scale,
                      scale: scale,
                      origenPx: topRulerHeight + offsetHojaY,
                      horizontal: false,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: topRulerHeight + offsetHojaY,
                left: leftRulerWidth + offsetHojaX,
                width: wPx,
                height: hPx,
                child: GestureDetector(
                  onTap: () => setState(() => _elementoSeleccionadoId = null),
                  child: Container(
                    width: wPx,
                    height: hPx,
                    decoration: BoxDecoration(
                      color: colorFromHex(hoja.colorFondoHex) ?? Colors.white,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final elemento in hoja.elementos)
                          ElementoBox(
                            key: ValueKey(elemento.id),
                            elemento: elemento,
                            scale: scale,
                            seleccionado:
                                elemento.id == _elementoSeleccionadoId,
                            onSelect: () => setState(
                              () => _elementoSeleccionadoId = elemento.id,
                            ),
                            onGeometriaChanged: (x, y, w, h) =>
                                _actualizarElemento(
                                  elemento.id,
                                  (e) => e.copyWith(
                                    x: x,
                                    y: y,
                                    width: w,
                                    height: h,
                                  ),
                                ),
                            onTextoChanged: elemento.tipo == TipoElemento.texto
                                ? (texto) => _actualizarElemento(
                                    elemento.id,
                                    (e) => e.copyWith(textoContenido: texto),
                                  )
                                : null,
                            onMapaChanged: elemento.tipo == TipoElemento.mapa
                                ? (lat, lng, zoom) => _actualizarElemento(
                                    elemento.id,
                                    (e) => e.copyWith(
                                      mapaLat: lat,
                                      mapaLng: lng,
                                      mapaZoom: zoom,
                                    ),
                                  )
                                : null,
                            predios: elemento.tipo == TipoElemento.mapa
                                ? _prediosParaElementoMapa(
                                    elemento,
                                    todosLosPredios,
                                  )
                                : elemento.tipo == TipoElemento.grafica
                                ? _filtrarPrediosDelProyecto(todosLosPredios)
                                : const [],
                            importedFeatures: elemento.tipo == TipoElemento.mapa
                                ? importedFeatures
                                : const [],
                            hojaElementos: elemento.tipo == TipoElemento.escala
                                ? hoja.elementos
                                : const [],
                            proyectoItem: elemento.tipo == TipoElemento.grafica
                                ? proyectoItem
                                : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Contenedor lateral derecho de las propiedades del elemento seleccionado.
  Widget _buildPanelLateralDerecho() {
    final elemento = _elementoSeleccionado;
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: const Text(
              'Propiedades',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: elemento == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Selecciona un elemento del lienzo para editar sus propiedades.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: _buildPanelPropiedadesContenido(elemento),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelPropiedadesContenido(ElementoComposicion elemento) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          elemento.nombreCapa,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 14),
        if (elemento.tipo == TipoElemento.forma)
          PanelPropiedadesForma(
            elemento: elemento,
            onColorTrazoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(colorTrazoHex: v),
            ),
            onGrosorChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(grosorTrazo: v),
            ),
            onColorRellenoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) =>
                  e.copyWith(clearColorRelleno: v == null, colorRellenoHex: v),
            ),
          ),
        if (elemento.tipo == TipoElemento.texto)
          PanelPropiedadesTexto(
            elemento: elemento,
            onTextoContenidoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoContenido: v),
            ),
            onFontFamilyChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoFontFamily: v),
            ),
            onFontSizeChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoFontSize: v),
            ),
            onBoldChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoBold: v),
            ),
            onItalicChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoItalic: v),
            ),
            onColorTextoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoColorHex: v),
            ),
            onColorFondoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(
                clearTextoColorFondo: v == null,
                textoColorFondoHex: v,
              ),
            ),
          ),
        if (elemento.tipo == TipoElemento.mapa)
          PanelPropiedadesMapa(
            elemento: elemento,
            onLatChanged: (v) =>
                _actualizarElemento(elemento.id, (e) => e.copyWith(mapaLat: v)),
            onLngChanged: (v) =>
                _actualizarElemento(elemento.id, (e) => e.copyWith(mapaLng: v)),
            onZoomChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(mapaZoom: v),
            ),
            onBaseLayerChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(mapaBaseLayer: v),
            ),
            onMostrarClavesChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(mapaMostrarClaves: v),
            ),
          ),
        if (elemento.tipo == TipoElemento.norte)
          PanelPropiedadesNorte(
            elemento: elemento,
            onRotacionChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(rotacion: v),
            ),
          ),
        if (elemento.tipo == TipoElemento.escala)
          PanelPropiedadesEscala(
            elemento: elemento,
            mapasDisponibles: _hojaActiva.elementos
                .where((e) => e.tipo == TipoElemento.mapa)
                .toList(),
            onMapaIdChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(clearEscalaMapaId: v == null, escalaMapaId: v),
            ),
          ),
        if (elemento.tipo == TipoElemento.simbologia)
          PanelPropiedadesSimbologia(
            elemento: elemento,
            onTipoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(simbologiaTipo: v),
            ),
          ),
        if (elemento.tipo == TipoElemento.grafica)
          PanelPropiedadesGrafica(
            elemento: elemento,
            onTipoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(graficaTipo: v),
            ),
          ),
      ],
    );
  }
}

class _ReglaHojaPainter extends CustomPainter {
  const _ReglaHojaPainter({
    required this.longitudMm,
    required this.scale,
    required this.origenPx,
    required this.horizontal,
  });

  final double longitudMm;
  final double scale;
  final double origenPx;
  final bool horizontal;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 1.5;
    final textStyle = const TextStyle(color: Color(0xFF666666), fontSize: 8);

    final pixelsPerMm = scale;
    final numTicks = longitudMm.floor();

    for (var i = 0; i <= numTicks; i++) {
      final pos = origenPx + i * pixelsPerMm;

      // Verificar que la posición está dentro de los límites
      if (horizontal && pos > size.width) break;
      if (!horizontal && pos > size.height) break;
      if (horizontal && pos < 0) continue;
      if (!horizontal && pos < 0) continue;

      final isMajorTick = i % 10 == 0;
      final lineLength = isMajorTick ? 10.0 : 5.0;

      if (horizontal) {
        canvas.drawLine(Offset(pos, 0), Offset(pos, lineLength), paint);

        if (isMajorTick) {
          final textPainter = TextPainter(
            text: TextSpan(text: '${i ~/ 10}', style: textStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(pos - textPainter.width / 2, lineLength + 2),
          );
        }
      } else {
        canvas.drawLine(Offset(0, pos), Offset(lineLength, pos), paint);

        if (isMajorTick) {
          final textPainter = TextPainter(
            text: TextSpan(text: '${i ~/ 10}', style: textStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(lineLength + 2, pos - textPainter.height / 2),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReglaHojaPainter oldDelegate) => false;
}
