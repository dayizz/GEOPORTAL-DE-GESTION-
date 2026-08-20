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
  ConsumerState<ComposicionEditorScreen> createState() => _ComposicionEditorScreenState();
}

class _ComposicionEditorScreenState extends ConsumerState<ComposicionEditorScreen> {
  Composicion? _composicion;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  int _hojaActivaIndex = 0;
  String? _elementoSeleccionadoId;
  int _contadorInsertados = 0;
  bool _exportando = false;
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
    if (proyecto == null || proyecto.isEmpty) return const [];
    return todos.where((p) => _predioPerteneceAProyecto(p, proyecto)).toList(growable: false);
  }

  bool _predioPerteneceAProyecto(Predio predio, String proyecto) {
    final directo = predio.proyecto?.trim().toUpperCase();
    if (directo != null && directo.isNotEmpty) {
      if (directo == proyecto) return true;
      if (directo == 'TQM' && proyecto == 'TMQ') return true;
      return false;
    }
    final compact = predio.claveCatastral.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    switch (proyecto) {
      case 'TQI':
        return compact.startsWith('TQI') || compact.startsWith('QI');
      case 'TSNL':
        return compact.startsWith('TSNL') || compact.startsWith('SNL') || compact.startsWith('SL');
      case 'TAP':
        return compact.startsWith('TAP') || compact.startsWith('AP');
      case 'TMQ':
        return compact.startsWith('TMQ') || compact.startsWith('TQM') || compact.startsWith('QM');
      default:
        return false;
    }
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

  void _actualizarElemento(String id, ElementoComposicion Function(ElementoComposicion) actualizar) {
    _actualizarHoja((hoja) {
      final elementos = hoja.elementos.map((e) => e.id == id ? actualizar(e) : e).toList();
      return hoja.copyWith(elementos: elementos);
    });
  }

  void _agregarElemento(ElementoComposicion Function(double x, double y) crear) {
    _contadorInsertados++;
    final offset = (_contadorInsertados % 8) * 10.0;
    final elemento = crear(20 + offset, 20 + offset);
    _actualizarHoja((hoja) => hoja.copyWith(elementos: [...hoja.elementos, elemento]));
    setState(() => _elementoSeleccionadoId = elemento.id);
  }

  void _eliminarElemento(String id) {
    _actualizarHoja((hoja) => hoja.copyWith(elementos: hoja.elementos.where((e) => e.id != id).toList()));
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
      final hojas = List<Hoja>.from(_composicion!.hojas)..removeAt(_hojaActivaIndex);
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
          const SnackBar(content: Text('Composición guardada.'), backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e'), backgroundColor: AppColors.danger),
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

  void _mostrarProximamente() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disponible próximamente.')),
    );
  }

  /// Selecciona una imagen local, la comprime/redimensiona a JPEG (no hay
  /// Storage habilitado en este proyecto -ver `storage.rules`-, así que
  /// se embebe como base64 directo en el documento de la composición) y
  /// la agrega como nuevo elemento.
  Future<void> _importarImagen() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final decodificada = img.decodeImage(bytes);
    if (decodificada == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer la imagen.'), backgroundColor: AppColors.danger),
        );
      }
      return;
    }

    const dimensionMaxPx = 1600;
    var redimensionada = decodificada;
    if (decodificada.width > dimensionMaxPx || decodificada.height > dimensionMaxPx) {
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
    _agregarElemento((x, y) => ElementoComposicion.imagen(
          base64: base64Str,
          x: x,
          y: y,
          width: anchoMaxMm,
          height: anchoMaxMm * aspecto,
        ));
  }

  List<Predio> _prediosParaExportar() =>
      _filtrarPrediosDelProyecto(ref.read(prediosMapaProvider).valueOrNull ?? const []);

  ProyectoItem? _proyectoItemParaExportar() =>
      _proyectoItemDe(ref.read(proyectosProvider).valueOrNull ?? const <ProyectoItem>[]);

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
          mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        );
      });

  Future<void> _ejecutarExportacion(Future<void> Function() accion) async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      await accion();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exportado correctamente.'), backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo exportar: $e'), backgroundColor: AppColors.danger),
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
    final predios = _filtrarPrediosDelProyecto(ref.watch(prediosMapaProvider).valueOrNull ?? const []);
    final proyectoItem = _proyectoItemDe(ref.watch(proyectosProvider).valueOrNull ?? const <ProyectoItem>[]);

    return AppScaffold(
      currentIndex: 7,
      title: composicion.nombre,
      actions: [
        IconButton(
          tooltip: 'Renombrar',
          icon: const Icon(Icons.edit_outlined),
          onPressed: _renombrar,
        ),
        PopupMenuButton<String>(
          tooltip: 'Más opciones',
          enabled: !_exportando,
          icon: _exportando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'importar':
                _importarImagen();
                break;
              case 'png':
                _exportarPng();
                break;
              case 'jpg':
                _exportarJpg();
                break;
              case 'pdf':
                _exportarPdf();
                break;
              case 'pptx':
                _exportarPptx();
                break;
              default:
                _mostrarProximamente();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'importar', child: Text('Importar/adjuntar imagen')),
            PopupMenuItem(value: 'png', child: Text('Exportar PNG (hoja activa)')),
            PopupMenuItem(value: 'jpg', child: Text('Exportar JPG (hoja activa)')),
            PopupMenuItem(value: 'pdf', child: Text('Exportar PDF (todas las hojas)')),
            PopupMenuItem(value: 'pptx', child: Text('Exportar PPTX (todas las hojas)')),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: ElevatedButton.icon(
            // El tema global fuerza minimumSize: Size(double.infinity, 48)
            // en todo ElevatedButton (pensado para botones de ancho
            // completo en formularios); dentro del Row de acciones de una
            // AppBar un ancho infinito rompe el layout completo de la
            // barra. Se anula aquí con un tamaño acotado.
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(64, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Guardar'),
          ),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBarraLateral(predios),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _buildBarraHojas(),
                const Divider(height: 1),
                Expanded(child: _buildLienzo(predios, proyectoItem)),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          _buildPanelLateralDerecho(),
        ],
      ),
    );
  }

  Future<void> _renombrar() async {
    final ctrl = TextEditingController(text: _composicion!.nombre);
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar composición'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
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
          Padding(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                _herramientaBoton(
                  icon: Icons.description_outlined,
                  tooltip: 'Hoja',
                  onTap: () async {
                    final resultado = await mostrarHerramientaHojaDialog(context, hoja: _hojaActiva);
                    if (resultado == null) return;
                    _actualizarHoja((hoja) => hoja.copyWith(
                          tamano: resultado.tamano,
                          horizontal: resultado.horizontal,
                          margenMm: resultado.margenMm,
                          clearColorFondo: resultado.colorFondoHex == null,
                          colorFondoHex: resultado.colorFondoHex,
                        ));
                  },
                ),
                const SizedBox(width: 4),
                _herramientaBoton(
                  icon: Icons.crop_square_outlined,
                  tooltip: 'Mapa',
                  onTap: () {
                    final (lat, lng) = _centroPorDefecto(predios);
                    _agregarElemento((x, y) => ElementoComposicion.mapa(
                          lat: lat,
                          lng: lng,
                          zoom: 14,
                          proyecto: _composicion!.proyecto,
                          x: x,
                          y: y,
                        ));
                  },
                ),
                const SizedBox(width: 4),
                _herramientaFigurasBoton(),
                const SizedBox(width: 4),
                _herramientaBoton(
                  icon: Icons.text_fields,
                  tooltip: 'Texto',
                  onTap: () => _agregarElemento((x, y) => ElementoComposicion.texto(x: x, y: y)),
                ),
                const SizedBox(width: 4),
                _herramientaNorteBoton(),
                const SizedBox(width: 4),
                _herramientaEscalaBoton(),
                const SizedBox(width: 4),
                _herramientaSimbologiaBoton(),
                const SizedBox(width: 4),
                _herramientaGraficaBoton(),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text('Capas', style: Theme.of(context).textTheme.titleSmall),
          ),
          Expanded(
            child: CapasPanel(
              elementos: _hojaActiva.elementos,
              seleccionadoId: _elementoSeleccionadoId,
              onSelect: (id) => setState(() => _elementoSeleccionadoId = id),
              onReorder: _reordenarElemento,
              onToggleVisible: (id) => _actualizarElemento(id, (e) => e.copyWith(visible: !e.visible)),
              onToggleBloqueado: (id) => _actualizarElemento(id, (e) => e.copyWith(bloqueado: !e.bloqueado)),
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
          child: Icon(icon, size: 16, color: deshabilitada ? AppColors.textLight : AppColors.textPrimary),
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
          child: const Icon(Icons.category_outlined, size: 16, color: AppColors.textPrimary),
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
                          colorRelleno: tipo == TipoFigura.linea || tipo == TipoFigura.lineaPunteada
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
      onTap: () => _agregarElemento((x, y) => ElementoComposicion.norte(x: x, y: y)),
    );
  }

  Widget _herramientaEscalaBoton() {
    return _herramientaBoton(
      icon: Icons.straighten_outlined,
      tooltip: 'Escala gráfica',
      onTap: () {
        final mapasEnHoja = _hojaActiva.elementos.where((e) => e.tipo == TipoElemento.mapa);
        final mapaId = mapasEnHoja.isEmpty ? null : mapasEnHoja.first.id;
        _agregarElemento((x, y) => ElementoComposicion.escala(x: x, y: y, mapaId: mapaId));
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
          PopupMenuItem(value: TipoSimbologia.rangoEstatus, child: Text('Rango de estatus')),
          PopupMenuItem(value: TipoSimbologia.tipoPropiedad, child: Text('Tipo de propiedad')),
        ],
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.palette_outlined, size: 16, color: AppColors.textPrimary),
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
          (x, y) => ElementoComposicion.grafica(tipo: tipo, proyecto: _composicion!.proyecto, x: x, y: y),
        ),
        itemBuilder: (context) => const [
          PopupMenuItem(value: TipoGrafica.kpiPanel, child: Text('KPIs (avance de proyecto)')),
          PopupMenuItem(value: TipoGrafica.avanceDdv, child: Text('Avance DDV')),
          PopupMenuItem(value: TipoGrafica.rangoEstatus, child: Text('Rango de estatus')),
          PopupMenuItem(value: TipoGrafica.tipoLiberacion, child: Text('Tipo de liberación')),
          PopupMenuItem(value: TipoGrafica.tipoPropiedad, child: Text('Avance por tipo de propiedad')),
          PopupMenuItem(value: TipoGrafica.segmentoTramoFrente, child: Text('Avance por segmento/tramo/frente')),
          PopupMenuItem(value: TipoGrafica.cadenamiento, child: Text('Diagrama por cadenamiento')),
          PopupMenuItem(value: TipoGrafica.avanceMensual, child: Text('Avance mensual')),
          PopupMenuItem(value: TipoGrafica.avanceSemanal, child: Text('Avance semanal')),
        ],
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.bar_chart_outlined, size: 16, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildBarraHojas() {
    final hojas = _composicion!.hojas;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hojas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final activa = index == _hojaActivaIndex;
                return ChoiceChip(
                  label: Text(hojas[index].nombre, style: const TextStyle(fontSize: 12)),
                  selected: activa,
                  onSelected: (_) => setState(() {
                    _hojaActivaIndex = index;
                    _elementoSeleccionadoId = null;
                  }),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Insertar otra hoja',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: _agregarHoja,
          ),
          IconButton(
            tooltip: 'Eliminar hoja activa',
            icon: const Icon(Icons.delete_outline),
            onPressed: hojas.length > 1 ? _eliminarHojaActiva : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLienzo(List<Predio> predios, ProyectoItem? proyectoItem) {
    final hoja = _hojaActiva;
    final (anchoMm, altoMm) = hoja.dimensionesMm;

    return Container(
      color: const Color(0xFFE9ECF2),
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaleAncho = constraints.maxWidth / anchoMm;
          final scaleAlto = constraints.maxHeight / altoMm;
          final scale = (scaleAncho < scaleAlto ? scaleAncho : scaleAlto) * 0.94;
          final wPx = anchoMm * scale;
          final hPx = altoMm * scale;

          return Center(
            child: GestureDetector(
              onTap: () => setState(() => _elementoSeleccionadoId = null),
              child: Container(
                width: wPx,
                height: hPx,
                decoration: BoxDecoration(
                  color: colorFromHex(hoja.colorFondoHex) ?? Colors.white,
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final elemento in hoja.elementos)
                      ElementoBox(
                        key: ValueKey(elemento.id),
                        elemento: elemento,
                        scale: scale,
                        seleccionado: elemento.id == _elementoSeleccionadoId,
                        onSelect: () => setState(() => _elementoSeleccionadoId = elemento.id),
                        onGeometriaChanged: (x, y, w, h) => _actualizarElemento(
                          elemento.id,
                          (e) => e.copyWith(x: x, y: y, width: w, height: h),
                        ),
                        onTextoChanged: elemento.tipo == TipoElemento.texto
                            ? (texto) => _actualizarElemento(elemento.id, (e) => e.copyWith(textoContenido: texto))
                            : null,
                        onMapaChanged: elemento.tipo == TipoElemento.mapa
                            ? (lat, lng, zoom) => _actualizarElemento(
                                  elemento.id,
                                  (e) => e.copyWith(mapaLat: lat, mapaLng: lng, mapaZoom: zoom),
                                )
                            : null,
                        predios: elemento.tipo == TipoElemento.mapa || elemento.tipo == TipoElemento.grafica
                            ? predios
                            : const [],
                        hojaElementos: elemento.tipo == TipoElemento.escala ? hoja.elementos : const [],
                        proyectoItem: elemento.tipo == TipoElemento.grafica ? proyectoItem : null,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Contenedor lateral derecho de las propiedades del elemento seleccionado.
  Widget _buildPanelLateralDerecho() {
    final elemento = _elementoSeleccionado;
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            Text(elemento.nombreCapa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 14),
            if (elemento.tipo == TipoElemento.forma)
              PanelPropiedadesForma(
                elemento: elemento,
                onColorTrazoChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(colorTrazoHex: v)),
                onGrosorChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(grosorTrazo: v)),
                onColorRellenoChanged: (v) => _actualizarElemento(
                  elemento.id,
                  (e) => e.copyWith(clearColorRelleno: v == null, colorRellenoHex: v),
                ),
              ),
            if (elemento.tipo == TipoElemento.texto)
              PanelPropiedadesTexto(
                elemento: elemento,
                onFontFamilyChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(textoFontFamily: v)),
                onFontSizeChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(textoFontSize: v)),
                onBoldChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(textoBold: v)),
                onItalicChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(textoItalic: v)),
                onColorTextoChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(textoColorHex: v)),
                onColorFondoChanged: (v) => _actualizarElemento(
                  elemento.id,
                  (e) => e.copyWith(clearTextoColorFondo: v == null, textoColorFondoHex: v),
                ),
              ),
            if (elemento.tipo == TipoElemento.mapa)
              PanelPropiedadesMapa(
                elemento: elemento,
                onBaseLayerChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(mapaBaseLayer: v)),
                onMostrarClavesChanged: (v) =>
                    _actualizarElemento(elemento.id, (e) => e.copyWith(mapaMostrarClaves: v)),
              ),
            if (elemento.tipo == TipoElemento.norte)
              PanelPropiedadesNorte(
                elemento: elemento,
                onRotacionChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(rotacion: v)),
              ),
            if (elemento.tipo == TipoElemento.escala)
              PanelPropiedadesEscala(
                elemento: elemento,
                mapasDisponibles: _hojaActiva.elementos.where((e) => e.tipo == TipoElemento.mapa).toList(),
                onMapaIdChanged: (v) => _actualizarElemento(
                  elemento.id,
                  (e) => e.copyWith(clearEscalaMapaId: v == null, escalaMapaId: v),
                ),
              ),
            if (elemento.tipo == TipoElemento.simbologia)
              PanelPropiedadesSimbologia(
                elemento: elemento,
                onTipoChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(simbologiaTipo: v)),
              ),
            if (elemento.tipo == TipoElemento.grafica)
              PanelPropiedadesGrafica(
                elemento: elemento,
                onTipoChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(graficaTipo: v)),
              ),
          ],
        );
  }
}
