import 'dart:math' as math;
import 'widgets/tema_panel_propiedades.dart';
import '../utils/limites_hoja.dart';
import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../estructura/models/proyecto_item.dart';
import '../../estructura/providers/proyectos_provider.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../../mapa/providers/capas_guardadas.dart';
import '../../mapa/utils/geometry_parsing.dart';
import '../../predios/models/predio.dart';
import '../../predios/providers/predios_provider.dart';
import '../models/composicion.dart';
import '../models/elemento_composicion.dart';
import '../models/hoja.dart';
import '../providers/composiciones_provider.dart';
import '../services/composicion_export_service.dart';
import '../utils/color_hex.dart';
import '../utils/datos_grafica.dart';
import '../utils/tabla_ops.dart';
import '../utils/capas_carpetas.dart';
import '../utils/portapapeles_navegador.dart';
import '../utils/iconos_composicion.dart';
import 'widgets/capas_panel.dart';
import 'widgets/elemento_box.dart';
import 'widgets/panel_propiedades_hoja.dart';
import 'widgets/panel_propiedades_icono.dart';
import 'widgets/numero_pagina_widget.dart';
import 'widgets/panel_propiedades_escala.dart';
import 'widgets/panel_propiedades_forma.dart';
import 'widgets/panel_propiedades_grafica.dart';
import 'widgets/panel_propiedades_tabla.dart';
import 'widgets/tabla_widget.dart';
import 'widgets/panel_propiedades_mapa.dart';
import 'widgets/panel_propiedades_norte.dart';
import 'widgets/panel_propiedades_simbologia.dart';
import 'widgets/panel_propiedades_texto.dart';
import 'widgets/shape_painter.dart';
import 'widgets/snap_indicator.dart';

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
  bool _mostrarFiguras = false;

  /// Selector de gráficas en el panel Propiedades (en vez de un menú
  /// emergente) y los datos elegidos para la gráfica nueva.
  bool _mostrarGraficas = false;
  String? _nuevaGraficaProyecto;
  String? _nuevaGraficaFiltro;
  TipoGrafica _nuevaGraficaTipo = TipoGrafica.kpiPanel;

  /// Alto/ancho del contenido de cada gráfica (lo informa `GraficaWidget`),
  /// para que el elemento mida solo lo que ocupa su contenido.
  final Map<String, double> _aspectoGrafica = {};

  /// Gráficas cuyo alto se ajusta al contenido: solo al crearlas, al
  /// cambiar sus datos o con "Ajustar al contenido", para que después se
  /// puedan estirar libremente. Se mantienen un momento en la lista porque
  /// el contenido puede re-medirse al terminar de cargar fuentes/datos.
  final Set<String> _graficasPorAjustar = {};

  void _marcarAjusteGrafica(String id) {
    _graficasPorAjustar.add(id);
    final aspecto = _aspectoGrafica[id];
    if (aspecto != null) _ajustarAltoGrafica(id, aspecto);
    Future.delayed(const Duration(seconds: 2), () => _graficasPorAjustar.remove(id));
  }

  // Caché de predios por proyecto para las gráficas (se invalida cuando
  // cambia la lista de predios).
  List<Predio>? _fuentePrediosGraficas;
  final Map<String, List<Predio>> _prediosGraficaPorProyecto = {};

  ResolverDatosGrafica _resolverDatosGrafica(List<Predio> todos, List<ProyectoItem> proyectos) {
    if (!identical(_fuentePrediosGraficas, todos)) {
      _fuentePrediosGraficas = todos;
      _prediosGraficaPorProyecto.clear();
    }
    return (String? codigo) {
      final proyecto = (codigo == null || codigo.trim().isEmpty ? _composicion?.proyecto ?? '' : codigo)
          .trim()
          .toUpperCase();
      ProyectoItem? item;
      for (final p in proyectos) {
        if (p.nombre.trim().toUpperCase() == proyecto) {
          item = p;
          break;
        }
      }
      final predios = _prediosGraficaPorProyecto.putIfAbsent(
        proyecto,
        () => todos.where((p) => _predioPerteneceAProyecto(p, proyecto)).toList(growable: false),
      );
      return (predios: predios, proyecto: item);
    };
  }

  List<String> _segmentosGraficaDe(String? proyecto, ResolverDatosGrafica resolver) {
    final datos = resolver(proyecto);
    return segmentosGrafica(datos.predios, datos.proyecto);
  }

  /// Ajusta el alto de la gráfica [id] a su contenido (ancho × [aspecto]).
  void _ajustarAltoGrafica(String id, double aspecto) {
    if (!mounted || aspecto <= 0) return;
    _aspectoGrafica[id] = aspecto;
    if (!_graficasPorAjustar.contains(id)) return;
    final e = _hojaActiva.elementos.where((el) => el.id == id).firstOrNull;
    if (e == null || (e.height - e.width * aspecto).abs() < 0.3) return;
    _actualizarElemento(id, (el) => el.copyWith(height: el.width * aspecto));
  }

  void _agregarGraficaNueva() {
    _agregarElemento(
      (x, y) => ElementoComposicion.grafica(
        tipo: _nuevaGraficaTipo,
        proyecto: _nuevaGraficaProyecto ?? _composicion!.proyecto,
        filtro: _nuevaGraficaFiltro,
        x: x,
        y: y,
      ),
    );
    final id = _elementoSeleccionadoId;
    if (id != null) _marcarAjusteGrafica(id);
  }

  /// Celdas seleccionadas / en edición de la tabla [_tablaSelId]. Solo
  /// cuentan mientras esa tabla sigue seleccionada (ver [_tablaSeleccion]).
  String? _tablaSelId;
  Set<CeldaTabla> _tablaSel = {};
  CeldaTabla? _tablaAncla;
  CeldaTabla? _tablaEditandoCelda;

  bool get _tablaActiva =>
      _tablaSelId != null && _tablaSelId == _elementoSeleccionadoId;
  Set<CeldaTabla> get _tablaSeleccion => _tablaActiva ? _tablaSel : const {};
  CeldaTabla? get _tablaEditando => _tablaActiva ? _tablaEditandoCelda : null;

  /// Clic: selecciona la celda. Shift+clic: rango desde la última celda.
  /// Ctrl/Cmd+clic: agrega o quita la celda. Doble clic: escribir en ella.
  void _tocarCeldaTabla(String id, CeldaTabla celda, {required bool doble}) {
    final teclado = HardwareKeyboard.instance;
    // Un campo del panel que siguiera con el foco se quedaría con los
    // atajos de copiar/pegar en vez de la tabla.
    final foco = FocusManager.instance.primaryFocus;
    final campo = foco?.context;
    if (campo != null &&
        (campo.widget is EditableText || campo.findAncestorWidgetOfExactType<EditableText>() != null)) {
      foco!.unfocus();
    }
    setState(() {
      if (_tablaSelId != id) {
        _tablaSelId = id;
        _tablaSel = {};
        _tablaAncla = null;
      }
      _tablaEditandoCelda = null;
      if (doble) {
        _tablaSel = {celda};
        _tablaAncla = celda;
        _tablaEditandoCelda = celda;
      } else if (teclado.isShiftPressed && _tablaAncla != null) {
        final (f0, c0) = _tablaAncla!;
        final (f1, c1) = celda;
        _tablaSel = {
          for (var f = f0 < f1 ? f0 : f1; f <= (f0 < f1 ? f1 : f0); f++)
            for (var c = c0 < c1 ? c0 : c1; c <= (c0 < c1 ? c1 : c0); c++) (f, c),
        };
      } else if (teclado.isControlPressed || teclado.isMetaPressed) {
        _tablaSel = {..._tablaSel};
        if (!_tablaSel.remove(celda)) _tablaSel.add(celda);
        _tablaAncla = celda;
      } else {
        _tablaSel = {celda};
        _tablaAncla = celda;
      }
    });
  }

  void _escribirCeldaTabla(String id, CeldaTabla celda, String texto) {
    _actualizarElemento(id, (e) {
      final (f, c) = celda;
      final celdas = [for (final fila in e.tablaCeldas) [...fila]];
      if (f >= celdas.length) return e;
      while (celdas[f].length <= c) {
        celdas[f].add('');
      }
      celdas[f][c] = texto;
      return e.copyWith(tablaCeldas: celdas);
    });
  }

  /// Punto (px del lienzo) donde OSNAP imantó el elemento seleccionado en
  /// este instante -null si no hay snap activo-, para dibujar el
  /// indicador visual momentáneo (ver `SnapIndicator`).
  Offset? _snapIndicadorPx;
  int _contadorInsertados = 0;
  bool _exportando = false;
  double _zoomNivel = 1.0;
  final _exportService = ComposicionExportService();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_manejarTeclado);
    _quitarPortapapelesNavegador = escucharPortapapelesNavegador(
      alCopiar: _copiarDesdeNavegador,
      alPegar: _pegarDesdeNavegador,
    );
    // Clic derecho en una celda abre el menú propio de la tabla (copiar,
    // pegar, insertar...) en vez del menú del navegador.
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializar();
      // Los PKS guardados solo se cargaban al abrir el Mapa; sin esto,
      // "Etiquetas de PKS" no mostraba nada al entrar directo aquí.
      asegurarPksCargados(ref);
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_manejarTeclado);
    _quitarPortapapelesNavegador();
    _respaldoPortapapeles?.cancel();
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    super.dispose();
  }

  /// Supr / Retroceso (la tecla "delete" de Mac) eliminan el elemento
  /// seleccionado, igual que el botón de capas. Se ignora mientras se
  /// escribe en un campo de texto, con un diálogo abierto o si la capa
  /// está bloqueada.
  bool _manejarTeclado(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape && _tablaEditando != null) {
      setState(() => _tablaEditandoCelda = null);
      return true;
    }
    if (_manejarPortapapelesTabla(event)) return true;
    if (_manejarPortapapelesElemento(event)) return true;
    if (event.logicalKey != LogicalKeyboardKey.delete &&
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return false;
    }
    final id = _elementoSeleccionadoId;
    if (!mounted || id == null || _composicion == null) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final foco = FocusManager.instance.primaryFocus?.context;
    if (foco != null &&
        (foco.widget is EditableText ||
            foco.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    final elemento =
        _hojaActiva.elementos.where((e) => e.id == id).firstOrNull;
    if (elemento == null || elemento.bloqueado) return false;
    // Con celdas seleccionadas, Supr vacía esas celdas en vez de borrar
    // la tabla completa.
    if (elemento.tipo == TipoElemento.tabla && _tablaSeleccion.isNotEmpty) {
      for (final celda in _tablaSeleccion) {
        _escribirCeldaTabla(id, celda, '');
      }
      return true;
    }
    _eliminarElemento(id);
    return true;
  }

  late final void Function() _quitarPortapapelesNavegador;
  // En web, Ctrl/Cmd+C/X/V se resuelven con los eventos `copy`/`cut`/
  // `paste` del navegador; si alguno no llega (algunos navegadores no los
  // disparan fuera de un campo de texto), este temporizador usa la API de
  // portapapeles de Flutter como respaldo.
  Timer? _respaldoPortapapeles;

  /// Tabla seleccionada con celdas seleccionadas a la que aplican los
  /// atajos de portapapeles: no mientras se escribe en una celda o en un
  /// campo (ahí el campo usa el portapapeles nativo) ni con un diálogo.
  ElementoComposicion? get _tablaParaPortapapeles {
    final id = _elementoSeleccionadoId;
    if (!mounted || id == null || _composicion == null) return null;
    if (_tablaSeleccion.isEmpty || _tablaEditando != null) return null;
    if (ModalRoute.of(context)?.isCurrent == false) return null;
    final foco = FocusManager.instance.primaryFocus?.context;
    if (foco != null &&
        (foco.widget is EditableText ||
            foco.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return null;
    }
    final elemento = _hojaActiva.elementos.where((e) => e.id == id).firstOrNull;
    return elemento?.tipo == TipoElemento.tabla ? elemento : null;
  }

  /// Ctrl/Cmd + C copia el elemento seleccionado y Ctrl/Cmd + V lo pega,
  /// fuera de un campo de texto (las celdas de tabla seleccionadas tienen
  /// prioridad, ver [_manejarPortapapelesTabla]).
  bool _manejarPortapapelesElemento(KeyEvent event) {
    final teclado = HardwareKeyboard.instance;
    if (!teclado.isControlPressed && !teclado.isMetaPressed) return false;
    final copiar = event.logicalKey == LogicalKeyboardKey.keyC;
    if (!copiar && event.logicalKey != LogicalKeyboardKey.keyV) return false;
    if (!mounted || _composicion == null) return false;
    if (_tablaParaPortapapeles != null) return false;
    final id = _elementoSeleccionadoId;
    if (copiar ? id == null : _elementoCopiado == null) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final foco = FocusManager.instance.primaryFocus?.context;
    if (foco != null &&
        (foco.widget is EditableText ||
            foco.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    copiar ? _copiarElemento(id!) : _pegarElemento();
    return true;
  }

  /// Ctrl/Cmd + C, X o V con celdas de tabla seleccionadas. Las celdas
  /// viajan como texto separado por tabuladores y saltos de línea, el
  /// mismo formato que usan Excel y Google Sheets.
  bool _manejarPortapapelesTabla(KeyEvent event) {
    final teclado = HardwareKeyboard.instance;
    if (!teclado.isControlPressed && !teclado.isMetaPressed) return false;
    final tecla = event.logicalKey;
    if (tecla != LogicalKeyboardKey.keyC &&
        tecla != LogicalKeyboardKey.keyX &&
        tecla != LogicalKeyboardKey.keyV) {
      return false;
    }
    if (_tablaParaPortapapeles == null) return false;
    final cortar = tecla == LogicalKeyboardKey.keyX;
    final pegar = tecla == LogicalKeyboardKey.keyV;
    if (portapapelesNavegadorDisponible) {
      // Sin marcar la tecla como atendida, para que el navegador dispare
      // su evento de copiar/pegar (ver `_copiarDesdeNavegador`).
      _respaldoPortapapeles?.cancel();
      _respaldoPortapapeles = Timer(const Duration(milliseconds: 250), () {
        _respaldoPortapapeles = null;
        pegar ? _pegarDesdePortapapeles() : _copiarAlPortapapeles(cortar: cortar);
      });
      return false;
    }
    pegar ? _pegarDesdePortapapeles() : _copiarAlPortapapeles(cortar: cortar);
    return true;
  }

  String? _copiarDesdeNavegador(bool cortar) {
    final texto = _textoSeleccionTabla(cortar: cortar);
    if (texto != null) {
      _respaldoPortapapeles?.cancel();
      _respaldoPortapapeles = null;
    }
    return texto;
  }

  bool _pegarDesdeNavegador(String texto) {
    final elemento = _tablaParaPortapapeles;
    if (elemento == null) return false;
    _respaldoPortapapeles?.cancel();
    _respaldoPortapapeles = null;
    if (!elemento.bloqueado) _pegarTextoEnTabla(elemento.id, _tablaSeleccion, texto);
    return true;
  }

  void _copiarAlPortapapeles({required bool cortar}) {
    final texto = _textoSeleccionTabla(cortar: cortar);
    if (texto != null) Clipboard.setData(ClipboardData(text: texto));
  }

  Future<void> _pegarDesdePortapapeles() async {
    final elemento = _tablaParaPortapapeles;
    if (elemento == null || elemento.bloqueado) return;
    final seleccion = _tablaSeleccion;
    String? texto;
    try {
      texto = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      texto = null;
    }
    if (!mounted) return;
    if (texto == null || texto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo leer el portapapeles. Permite el acceso en el '
            'navegador o pega con Ctrl/Cmd+V.'),
      ));
      return;
    }
    _pegarTextoEnTabla(elemento.id, seleccion, texto);
  }

  /// Texto (TSV) del rectángulo que abarca la selección (las celdas no
  /// seleccionadas dentro de él van vacías); con [cortar] además vacía las
  /// celdas. `null` si no hay celdas de tabla que copiar.
  String? _textoSeleccionTabla({required bool cortar}) {
    final elemento = _tablaParaPortapapeles;
    if (elemento == null) return null;
    final seleccion = _tablaSeleccion;
    final filas = seleccion.map((c) => c.$1);
    final columnas = seleccion.map((c) => c.$2);
    final (f0, f1) = (filas.reduce(math.min), filas.reduce(math.max));
    final (c0, c1) = (columnas.reduce(math.min), columnas.reduce(math.max));
    String texto(int f, int c) {
      if (!seleccion.contains((f, c)) || f >= elemento.tablaCeldas.length) return '';
      final fila = elemento.tablaCeldas[f];
      return c < fila.length ? fila[c] : '';
    }
    final tsv = [
      for (var f = f0; f <= f1; f++)
        [for (var c = c0; c <= c1; c++) _celdaATsv(texto(f, c))].join('\t'),
    ].join('\n');
    if (cortar && !elemento.bloqueado) {
      for (final celda in seleccion) {
        _escribirCeldaTabla(elemento.id, celda, '');
      }
    }
    return tsv;
  }

  /// Menú de clic derecho sobre una celda: portapapeles e
  /// inserción/eliminación de filas y columnas junto a la selección.
  Future<void> _menuCeldaTabla(String id, CeldaTabla celda, Offset posicion) async {
    if (_tablaSelId != id || !_tablaSel.contains(celda)) {
      _tocarCeldaTabla(id, celda, doble: false);
    }
    final elemento = _hojaActiva.elementos.where((e) => e.id == id).firstOrNull;
    if (elemento == null) return;
    final seleccion = _tablaSeleccion;
    final filas = {for (final c in seleccion) c.$1};
    final columnas = {for (final c in seleccion) c.$2};
    final editable = !elemento.bloqueado;
    const item = _itemMenu;
    final accion = await _mostrarMenu(posicion, [
        item('copiar', Icons.copy, 'Copiar'),
        item('cortar', Icons.content_cut, 'Cortar', enabled: editable),
        item('pegar', Icons.content_paste, 'Pegar', enabled: editable),
        const PopupMenuDivider(),
        item('fila_arriba', Icons.vertical_align_top, 'Insertar fila arriba', enabled: editable),
        item('fila_abajo', Icons.vertical_align_bottom, 'Insertar fila abajo', enabled: editable),
        item('col_izq', Icons.west, 'Insertar columna a la izquierda', enabled: editable),
        item('col_der', Icons.east, 'Insertar columna a la derecha', enabled: editable),
        const PopupMenuDivider(),
        item('borrar_fila', Icons.delete_sweep_outlined, filas.length > 1 ? 'Eliminar filas' : 'Eliminar fila',
            enabled: editable && filas.length < elemento.tablaCeldas.length),
        item('borrar_col', Icons.delete_sweep_outlined, columnas.length > 1 ? 'Eliminar columnas' : 'Eliminar columna',
            enabled: editable && columnas.length < columnasTabla(elemento.tablaCeldas)),
        // La tabla completa, igual que el menú de los demás elementos.
        const PopupMenuDivider(),
        item('tabla_copiar', Icons.copy_all, 'Copiar tabla'),
        item('tabla_pegar', Icons.content_paste_go, 'Pegar elemento', enabled: _elementoCopiado != null),
        item('tabla_eliminar', Icons.delete_outline, 'Eliminar tabla', enabled: editable),
    ]);
    if (!mounted || accion == null) return;
    void reubicar(Set<CeldaTabla> nueva) => setState(() {
      _tablaSel = nueva;
      _tablaAncla = nueva.isEmpty ? null : nueva.first;
    });
    switch (accion) {
      case 'copiar':
        _copiarAlPortapapeles(cortar: false);
      case 'cortar':
        _copiarAlPortapapeles(cortar: true);
      case 'pegar':
        await _pegarDesdePortapapeles();
      case 'fila_arriba' || 'fila_abajo':
        final i = accion == 'fila_abajo' ? filas.reduce(math.max) + 1 : filas.reduce(math.min);
        _actualizarElemento(id, (e) => insertarFilaTabla(e, i));
        reubicar({for (final (f, c) in seleccion) (f >= i ? f + 1 : f, c)});
      case 'col_izq' || 'col_der':
        final j = accion == 'col_der' ? columnas.reduce(math.max) + 1 : columnas.reduce(math.min);
        _actualizarElemento(id, (e) => insertarColumnaTabla(e, j));
        reubicar({for (final (f, c) in seleccion) (f, c >= j ? c + 1 : c)});
      case 'borrar_fila':
        _actualizarElemento(id, (e) => eliminarFilasTabla(e, filas));
        reubicar({});
      case 'borrar_col':
        _actualizarElemento(id, (e) => eliminarColumnasTabla(e, columnas));
        reubicar({});
      case 'tabla_copiar':
        _copiarElemento(id);
      case 'tabla_pegar':
        _pegarElemento();
      case 'tabla_eliminar':
        _eliminarElemento(id);
    }
  }

  // Un salto de línea o tabulador dentro de la celda rompería el formato
  // de filas/columnas; se entrecomilla como hace Excel.
  static String _celdaATsv(String v) =>
      v.contains(RegExp(r'[\t\n"]')) ? '"${v.replaceAll('"', '""')}"' : v;

  /// Interpreta texto separado por tabuladores/saltos de línea (con celdas
  /// entrecomilladas al estilo Excel) como filas de celdas.
  static List<List<String>> _tsvACeldas(String texto) {
    final filas = <List<String>>[];
    var fila = <String>[];
    final celda = StringBuffer();
    var entreComillas = false;
    final t = texto.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (var i = 0; i < t.length; i++) {
      final ch = t[i];
      if (entreComillas) {
        if (ch == '"' && i + 1 < t.length && t[i + 1] == '"') {
          celda.write('"');
          i++;
        } else if (ch == '"') {
          entreComillas = false;
        } else {
          celda.write(ch);
        }
      } else if (ch == '"' && celda.isEmpty) {
        entreComillas = true;
      } else if (ch == '\t') {
        fila.add(celda.toString());
        celda.clear();
      } else if (ch == '\n') {
        fila.add(celda.toString());
        celda.clear();
        filas.add(fila);
        fila = <String>[];
      } else {
        celda.write(ch);
      }
    }
    // Excel termina lo copiado con un salto de línea: no crea fila extra.
    if (celda.isNotEmpty || fila.isNotEmpty) {
      fila.add(celda.toString());
      filas.add(fila);
    }
    return filas;
  }

  /// Pega el portapapeles a partir de la celda superior izquierda de la
  /// selección, agregando filas/columnas si no caben. Un solo valor con
  /// varias celdas seleccionadas se copia en todas ellas.
  void _pegarTextoEnTabla(String id, Set<CeldaTabla> seleccion, String texto) {
    final bloque = _tsvACeldas(texto);
    if (bloque.isEmpty) return;
    final f0 = seleccion.map((c) => c.$1).reduce(math.min);
    final c0 = seleccion.map((c) => c.$2).reduce(math.min);
    final unSoloValor = bloque.length == 1 && bloque.first.length == 1;
    final destino = <CeldaTabla, String>{
      if (unSoloValor && seleccion.length > 1)
        for (final celda in seleccion) celda: bloque.first.first
      else
        for (var i = 0; i < bloque.length; i++)
          for (var j = 0; j < bloque[i].length; j++) (f0 + i, c0 + j): bloque[i][j],
    };
    _actualizarElemento(id, (e) {
      // Las filas/columnas que faltan se agregan al final con la medida de
      // la última, y la tabla crece en vez de apretar las existentes.
      final filasNecesarias = destino.keys.map((c) => c.$1 + 1).reduce(math.max);
      final columnasNecesarias = destino.keys.map((c) => c.$2 + 1).reduce(math.max);
      while (e.tablaCeldas.length < filasNecesarias) {
        e = insertarFilaTabla(e, e.tablaCeldas.length);
      }
      while (columnasTabla(e.tablaCeldas) < columnasNecesarias) {
        e = insertarColumnaTabla(e, columnasTabla(e.tablaCeldas));
      }
      final celdas = [
        for (final fila in e.tablaCeldas)
          [...fila, ...List.filled(columnasTabla(e.tablaCeldas) - fila.length, '')],
      ];
      destino.forEach((celda, valor) => celdas[celda.$1][celda.$2] = valor);
      return e.copyWith(tablaCeldas: celdas);
    });
    setState(() {
      _tablaSel = destino.keys.toSet();
      _tablaAncla = (f0, c0);
    });
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
        _composicion = composicion.copyWith(hojas: composicion.hojas.map(aplicarMargenHoja).toList());
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

  List<Predio>? _fuentePrediosMapas;
  final Map<String, List<Predio>> _prediosMapasPorProyecto = {};

  List<Predio> _prediosParaElementoMapa(
    ElementoComposicion elemento,
    List<Predio> todos,
  ) {
    if (!identical(_fuentePrediosMapas, todos)) {
      _fuentePrediosMapas = todos;
      _prediosMapasPorProyecto.clear();
    }
    final clave = '${_composicion?.proyecto}|${elemento.mapaProyecto}';
    return _prediosMapasPorProyecto.putIfAbsent(clave, () {
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
    });
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
      hojas[_hojaActivaIndex] = aplicarMargenHoja(actualizar(hojas[_hojaActivaIndex]));
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
    var elemento = crear(20 + offset, 20 + offset);
    final base = _baseNumerada(elemento.tipo);
    if (base != null) elemento = elemento.copyWith(nombreCapa: _nombreNumerado(base));
    _actualizarHoja(
      (hoja) => hoja.copyWith(elementos: [...hoja.elementos, elemento]),
    );
    setState(() { _elementoSeleccionadoId = elemento.id; _mostrarFiguras = false; _mostrarGraficas = false; });
  }

  /// Mapas y textos se numeran en la hoja (Mapa 1, Texto 2, ...) para
  /// distinguirlos en capas y en los selectores de mapa.
  static String? _baseNumerada(TipoElemento tipo) => switch (tipo) {
    TipoElemento.mapa => 'Mapa',
    TipoElemento.texto => 'Texto',
    _ => null,
  };

  /// `"[base] n"` con n consecutivo al mayor ya usado en la hoja.
  String _nombreNumerado(String base) {
    final patron = RegExp('^${RegExp.escape(base)} (\\d+)\$');
    var mayor = 0;
    for (final e in _hojaActiva.elementos) {
      final n = int.tryParse(patron.firstMatch(e.nombreCapa)?.group(1) ?? '');
      if (n != null && n > mayor) mayor = n;
    }
    return '$base ${mayor + 1}';
  }

  /// Elemento copiado (con todas sus propiedades) para "Pegar", en esta
  /// hoja o en otra.
  ElementoComposicion? _elementoCopiado;

  void _copiarElemento(String id) {
    final elemento = _hojaActiva.elementos.where((e) => e.id == id).firstOrNull;
    if (elemento != null) setState(() => _elementoCopiado = elemento);
  }

  /// Pega una copia de [_elementoCopiado] al frente de la hoja activa, en
  /// [enMm] (esquina superior izquierda) o desplazada 5 mm del copiado, y
  /// la selecciona para cambiarle solo lo necesario (p. ej. el texto).
  void _pegarElemento({Offset? enMm}) {
    final copiado = _elementoCopiado;
    if (copiado == null) return;
    final base = _baseNumerada(copiado.tipo);
    var copia = copiado.duplicado(
      nombreCapa: base != null ? _nombreNumerado(base) : '${copiado.nombreCapa} (copia)',
    );
    if (enMm != null) copia = copia.copyWith(x: enMm.dx, y: enMm.dy);
    // Pegada en otra hoja, la carpeta del original no existe ahí.
    if (!_hojaActiva.carpetas.any((c) => c.id == copia.carpetaId)) {
      copia = copia.copyWith(clearCarpetaId: true);
    }
    _actualizarHoja((hoja) => hoja.copyWith(elementos: [...hoja.elementos, copia]));
    setState(() {
      _elementoSeleccionadoId = copia.id;
      // Pegar de nuevo deja la siguiente copia escalonada, no encimada.
      _elementoCopiado = copia;
    });
  }

  /// Menú de clic derecho sobre un elemento ([id]) o sobre el fondo de la
  /// hoja (`id == null`, pega en [enMm]).
  Future<void> _menuElemento(String? id, Offset posicion, {Offset? enMm}) async {
    final elemento = id == null ? null : _hojaActiva.elementos.where((e) => e.id == id).firstOrNull;
    if (elemento != null) setState(() => _elementoSeleccionadoId = elemento.id);
    final carpetas = _hojaActiva.carpetas;
    final accion = await _mostrarMenu(posicion, [
      _itemMenu('copiar', Icons.copy, 'Copiar', enabled: elemento != null),
      _itemMenu('pegar', Icons.content_paste, 'Pegar', enabled: _elementoCopiado != null),
      _itemMenu('eliminar', Icons.delete_outline, 'Eliminar',
          enabled: elemento != null && !elemento.bloqueado),
      if (elemento != null && carpetas.isNotEmpty) ...[
        const PopupMenuDivider(),
        for (final c in carpetas)
          _itemMenu('carpeta:${c.id}', Icons.drive_file_move_outline, 'Mover a ${c.nombre}',
              enabled: elemento.carpetaId != c.id),
        if (carpetas.any((c) => c.id == elemento.carpetaId))
          _itemMenu('sacar', Icons.folder_off_outlined, 'Sacar de carpeta'),
      ],
    ]);
    if (!mounted) return;
    if (accion != null && accion.startsWith('carpeta:')) {
      _actualizarElemento(elemento!.id, (e) => e.copyWith(carpetaId: accion.substring(8)));
      return;
    }
    switch (accion) {
      case 'sacar':
        _actualizarElemento(elemento!.id, (e) => e.copyWith(clearCarpetaId: true));
      case 'copiar':
        _copiarElemento(elemento!.id);
      case 'pegar':
        _pegarElemento(enMm: enMm);
      case 'eliminar':
        _eliminarElemento(elemento!.id);
    }
  }

  static PopupMenuItem<String> _itemMenu(String valor, IconData icono, String texto, {bool enabled = true}) =>
      PopupMenuItem(
        value: valor,
        enabled: enabled,
        height: 36,
        child: Row(children: [
          Icon(icono, size: 18),
          const SizedBox(width: 10),
          Text(texto, style: const TextStyle(fontSize: 13)),
        ]),
      );

  Future<String?> _mostrarMenu(Offset posicion, List<PopupMenuEntry<String>> items) {
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final local = overlay.globalToLocal(posicion);
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          local.dx, local.dy, overlay.size.width - local.dx, overlay.size.height - local.dy),
      items: items,
    );
  }

  void _eliminarElemento(String id) {
    _actualizarHoja(
      (hoja) => hoja.copyWith(
        elementos: hoja.elementos.where((e) => e.id != id).toList(),
      ),
    );
    if (_elementoSeleccionadoId == id) {
      setState(() { _elementoSeleccionadoId = null; _mostrarFiguras = false; _mostrarGraficas = false; });
    }
  }

  void _agregarHoja() {
    setState(() {
      final hojas = List<Hoja>.from(_composicion!.hojas)
        ..add(Hoja.nueva(nombre: 'Hoja ${_composicion!.hojas.length + 1}').copyWith(numerarPagina: _hojaActiva.numerarPagina, inicioPagina: _hojaActiva.inicioPagina, posicionPagina: _hojaActiva.posicionPagina));
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
      indiceHoja: _hojaActivaIndex,
      predios: _prediosParaExportar(),
      pksFeatures: ref.read(pksPointFeaturesProvider),
      proyectoItem: _proyectoItemParaExportar(),
      datosGrafica: _resolverDatosGrafica(
        ref.read(prediosMapaProvider).valueOrNull ?? const <Predio>[],
        ref.read(proyectosProvider).valueOrNull ?? const <ProyectoItem>[],
      ),
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
      indiceHoja: _hojaActivaIndex,
      predios: _prediosParaExportar(),
      pksFeatures: ref.read(pksPointFeaturesProvider),
      proyectoItem: _proyectoItemParaExportar(),
      datosGrafica: _resolverDatosGrafica(
        ref.read(prediosMapaProvider).valueOrNull ?? const <Predio>[],
        ref.read(proyectosProvider).valueOrNull ?? const <ProyectoItem>[],
      ),
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
      pksFeatures: ref.read(pksPointFeaturesProvider),
      proyectoItem: _proyectoItemParaExportar(),
      datosGrafica: _resolverDatosGrafica(
        ref.read(prediosMapaProvider).valueOrNull ?? const <Predio>[],
        ref.read(proyectosProvider).valueOrNull ?? const <ProyectoItem>[],
      ),
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
      pksFeatures: ref.read(pksPointFeaturesProvider),
      proyectoItem: _proyectoItemParaExportar(),
      datosGrafica: _resolverDatosGrafica(
        ref.read(prediosMapaProvider).valueOrNull ?? const <Predio>[],
        ref.read(proyectosProvider).valueOrNull ?? const <ProyectoItem>[],
      ),
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
    final pksFeatures = ref.watch(pksPointFeaturesProvider);
    final proyectoItem = _proyectoItemDe(
      ref.watch(proyectosProvider).valueOrNull ?? const <ProyectoItem>[],
    );

    return AppScaffold(
      currentIndex: 7,
      title: composicion.nombre,
      actions: const [],
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBarraLateral(todosLosPredios),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      _buildBarraAccionesSuperior(),
                      const Divider(height: 1),
                      Expanded(
                        child: _buildLienzo(
                          todosLosPredios,
                          proyectoItem,
                          importedFeatures,
                          pksFeatures,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 6,
        children: [
                  _herramientaBoton(
                    icon: Icons.description_outlined,
                    tooltip: 'Hoja',
                    onTap: () => setState(() { _elementoSeleccionadoId = null; _mostrarFiguras = false; _mostrarGraficas = false; }),
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
                    icon: Icons.horizontal_rule,
                    tooltip: 'Agregar línea',
                    onTap: () => _agregarElemento((x, y) => ElementoComposicion.forma(
                      figuraTipo: TipoFigura.linea, x: x, y: y, width: 100, height: 8,
                    )),
                  ),
                  const SizedBox(width: 6),
                  _herramientaBoton(
                    icon: Icons.text_fields,
                    tooltip: 'Texto',
                    onTap: () => _agregarElemento(
                      (x, y) => ElementoComposicion.texto(x: x, y: y),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _herramientaBoton(icon: Icons.table_chart_outlined, tooltip: 'Agregar tabla', onTap: () {
                    _agregarElemento((x, y) => ElementoComposicion.tabla(x: x, y: y, celdas: [
                      ['Columna 1', 'Columna 2', 'Columna 3'], ['', '', ''], ['', '', ''],
                    ]));
                  }),
                  const SizedBox(width: 6),
                  _herramientaNorteBoton(),
                  const SizedBox(width: 6),
                  _herramientaEscalaBoton(),
                  const SizedBox(width: 6),
                  _herramientaSimbologiaBoton(),
                  const SizedBox(width: 6),
                  _herramientaGraficaBoton(),
                  const SizedBox(width: 6),
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


  Widget _buildBarraLateral(List<Predio> predios) {
    return SizedBox(
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 4, 0),
            child: Row(
              children: [
                const Expanded(child: Text('Capas', style: TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  tooltip: 'Nueva carpeta',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  onPressed: () => _actualizarHoja(agregarCarpeta),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CapasPanel(
              hoja: _hojaActiva,
              seleccionadoId: _elementoSeleccionadoId,
              onSelect: (id) => setState(() => _elementoSeleccionadoId = id),
              onCambiarHoja: _actualizarHoja,
              onMenu: (id, posicion) => _menuElemento(id, posicion),
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
    (TipoFigura.cuadrado, 'Cuadrado'),
    (TipoFigura.triangulo, 'Triángulo'),
    (TipoFigura.hexagono, 'Hexágono'),
    (TipoFigura.pentagono, 'Pentágono'),
    (TipoFigura.circulo, 'Círculo'),
    (TipoFigura.cruz, 'Cruz'),
    (TipoFigura.estrella, 'Estrella'),
  ];

  Widget _herramientaFigurasBoton() => _herramientaBoton(
    icon: Icons.category_outlined,
    tooltip: 'Figuras',
    onTap: () => setState(() {
      _elementoSeleccionadoId = null;
      _mostrarFiguras = true;
      _mostrarGraficas = false;
    }),
  );

  /// Iconos básicos, debajo de las figuras en el mismo panel.
  Widget _selectorDeIconos() {
    return SizedBox(
      width: 216,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (clave, etiqueta, _) in iconosComposicion)
              Tooltip(
                message: etiqueta,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _agregarElemento((x, y) => ElementoComposicion.icono(
                    nombre: clave, etiqueta: etiqueta, x: x, y: y,
                  )),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: IconoComposicion(clave, size: 24, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  ResolverDatosGrafica _resolverDatosGraficaActual() => _resolverDatosGrafica(
    ref.watch(prediosMapaProvider).valueOrNull ?? const <Predio>[],
    ref.watch(proyectosProvider).valueOrNull ?? const <ProyectoItem>[],
  );

  /// Opciones de la gráfica nueva, en el panel Propiedades.
  Widget _selectorDeGraficas() {
    final proyecto = _nuevaGraficaProyecto ?? _composicion!.proyecto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gráficas', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Elige los datos y el tipo de gráfica para agregarla a la hoja.'),
        const SizedBox(height: 8),
        SeccionDatosGrafica(
          idCampos: 'nueva',
          proyecto: proyecto,
          filtro: _nuevaGraficaFiltro,
          tipo: _nuevaGraficaTipo,
          proyectos: ref.watch(proyectosCodigosProvider),
          segmentos: _segmentosGraficaDe(proyecto, _resolverDatosGraficaActual()),
          onProyectoChanged: (v) => setState(() {
            _nuevaGraficaProyecto = v;
            _nuevaGraficaFiltro = null;
          }),
          onFiltroChanged: (v) => setState(() => _nuevaGraficaFiltro = v),
          onTipoChanged: (v) => setState(() => _nuevaGraficaTipo = v),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _agregarGraficaNueva,
          icon: const Icon(Icons.add_chart, size: 18),
          label: const Text('Agregar a la hoja'),
        ),
      ],
    );
  }

  /// Selector integrado en el panel Propiedades.
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
                    onTap: () => _agregarElemento((x, y) => ElementoComposicion.forma(
                      figuraTipo: tipo, x: x, y: y, width: 120, height: 120,
                    )),
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
                          colorRelleno: tipo == TipoFigura.linea
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
          child:  Icon(
            Icons.palette_outlined,
            size: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _herramientaGraficaBoton() => _herramientaBoton(
    icon: Icons.bar_chart_outlined,
    tooltip: 'Gráfica (Balance)',
    onTap: () => setState(() {
      _elementoSeleccionadoId = null;
      _mostrarFiguras = false;
      _mostrarGraficas = true;
      _nuevaGraficaProyecto ??= _composicion!.proyecto;
    }),
  );

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
    List<Map<String, dynamic>> pksFeatures,
  ) {
    final hoja = _hojaActiva;
    final (anchoMm, altoMm) = hoja.dimensionesMm;
    final datosGrafica = _resolverDatosGrafica(
      todosLosPredios,
      ref.watch(proyectosProvider).valueOrNull ?? const <ProyectoItem>[],
    );
    // Fondo del área de trabajo acorde al tema; la hoja conserva su color.
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final colorRegla =
        oscuro ? AppColors.surfaceVariant : const Color(0xFFF4F5F7);
    return Container(
      color: oscuro ? AppColors.background : const Color(0xFFE9ECF2),
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
                  color: colorRegla,
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
                  color: colorRegla,
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
                  onTap: () => setState(() { _elementoSeleccionadoId = null; _mostrarFiguras = false; _mostrarGraficas = false; }),
                  onSecondaryTapDown: (d) => _menuElemento(null, d.globalPosition, enMm: d.localPosition / scale),
                  child: Container(
                    width: wPx,
                    height: hPx,
                    decoration: BoxDecoration(
                      color: aplicarOpacidad(colorFromHex(hoja.colorFondoHex) ?? Colors.white, hoja.opacidadFondo),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _TemaHoja(child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (hoja.margenArriba + hoja.margenAbajo + hoja.margenIzquierda + hoja.margenDerecha > 0)
                          Positioned(
                            left: hoja.margenIzquierda * scale,
                            top: hoja.margenArriba * scale,
                            right: hoja.margenDerecha * scale,
                            bottom: hoja.margenAbajo * scale,
                            child: IgnorePointer(child: DecoratedBox(
                              decoration: BoxDecoration(border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.4))),
                            )),
                          ),
                        for (final elemento in hoja.elementos)
                          ElementoBox(
                            key: ValueKey(elemento.id),
                            elemento: elemento,
                            scale: scale,
                            hojaAnchoMm: anchoMm,
                            hojaAltoMm: altoMm,
                            margenesMm: EdgeInsets.fromLTRB(hoja.margenIzquierda, hoja.margenArriba, hoja.margenDerecha, hoja.margenAbajo),
                            onSnapIndicador: (p) {
                              if (_snapIndicadorPx != p) {
                                setState(() => _snapIndicadorPx = p);
                              }
                            },
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
                            datosGrafica: elemento.tipo == TipoElemento.grafica
                                ? datosGrafica
                                : null,
                            onAspectoGrafica: elemento.tipo == TipoElemento.grafica
                                ? (a) => _ajustarAltoGrafica(elemento.id, a)
                                : null,
                            tablaSeleccion: elemento.id == _tablaSelId
                                ? _tablaSeleccion
                                : const {},
                            tablaEditando: elemento.id == _tablaSelId
                                ? _tablaEditando
                                : null,
                            onCeldaTap: elemento.tipo == TipoElemento.tabla
                                ? (celda, {required doble}) =>
                                    _tocarCeldaTabla(elemento.id, celda, doble: doble)
                                : null,
                            onCeldaChanged: elemento.tipo == TipoElemento.tabla
                                ? (celda, texto) =>
                                    _escribirCeldaTabla(elemento.id, celda, texto)
                                : null,
                            onMenu: (posicion) => _menuElemento(elemento.id, posicion),
                            onCeldaMenu: elemento.tipo == TipoElemento.tabla
                                ? (celda, posicion) => _menuCeldaTabla(elemento.id, celda, posicion)
                                : null,
                            onTablaRedimensionar: elemento.tipo == TipoElemento.tabla
                                ? (f) => _actualizarElemento(elemento.id, f)
                                : null,
                            onTablaEdicionTerminada: () =>
                                setState(() => _tablaEditandoCelda = null),
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
                            pksFeatures: elemento.tipo == TipoElemento.mapa
                                ? pksFeatures
                                : const [],
                            hojaElementos: elemento.tipo == TipoElemento.escala ||
                                    elemento.tipo == TipoElemento.norte
                                ? hoja.elementos
                                : const [],
                            proyectoItem: elemento.tipo == TipoElemento.grafica
                                ? proyectoItem
                                : null,
                          ),
                        Positioned.fill(child: NumeroPaginaWidget(hoja: hoja, indice: _hojaActivaIndex, scale: scale)),
                        if (_snapIndicadorPx != null)
                          Positioned(
                            left: _snapIndicadorPx!.dx - 8,
                            top: _snapIndicadorPx!.dy - 8,
                            child: const SnapIndicator(),
                          ),
                      ],
                    )),
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
    return TemaPanelPropiedades(child: SizedBox(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: elemento == null && _mostrarGraficas
                  ? _selectorDeGraficas()
                  : elemento == null && _mostrarFiguras
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Figuras', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Selecciona una figura para agregarla a la hoja.'),
                      const SizedBox(height: 8),
                      _selectorDeFiguras(),
                      const SizedBox(height: 16),
                      const Text('Iconos', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Selecciona un icono para agregarlo a la hoja.'),
                      const SizedBox(height: 8),
                      _selectorDeIconos(),
                    ])
                  : elemento == null
                  ? PanelPropiedadesHoja(
                      key: ValueKey(_hojaActiva.id),
                      hoja: _hojaActiva,
                      onChanged: (hoja) => _actualizarHoja((_) => hoja),
                      onNumeracionChanged: (hoja) => setState(() {
                        _composicion = _composicion!.copyWith(hojas: _composicion!.hojas.map((h) => h.copyWith(
                          numerarPagina: hoja.numerarPagina, inicioPagina: hoja.inicioPagina, posicionPagina: hoja.posicionPagina,
                        )).toList());
                      }),
                    )
                  : _buildPanelPropiedadesContenido(elemento),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildPanelPropiedadesContenido(ElementoComposicion elemento) {
    return Column(
      key: ValueKey(elemento.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                elemento.nombreCapa,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
            onEstiloLineaChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(estiloLinea: v),
            ),
            onEspaciadoLineaChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(estiloLineaEspaciado: v),
            ),
            onColorRellenoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) =>
                  e.copyWith(clearColorRelleno: v == null, colorRellenoHex: v),
            ),
            onPuntaTipoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) {
                final sinExtremoElegido =
                    !(e.lineaPuntaIzquierda ?? false) &&
                    !(e.lineaPuntaDerecha ?? false);
                return e.copyWith(
                  lineaPuntaTipo: v,
                  lineaPuntaDerecha:
                      v != TipoPuntaLinea.ninguna && sinExtremoElegido
                      ? true
                      : null,
                );
              },
            ),
            onPuntaTamanoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(lineaPuntaTamano: v),
            ),
            onPuntaIzquierdaChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(lineaPuntaIzquierda: v),
            ),
            onPuntaDerechaChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(lineaPuntaDerecha: v),
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
            onSubrayadoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoSubrayado: v),
            ),
            onTachadoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoTachado: v),
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
            onBufferActivoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoBufferActivo: v),
            ),
            onBufferColorChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoBufferColorHex: v),
            ),
            onBufferAnchoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoBufferAncho: v),
            ),
            onAlineacionChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoAlineacion: v),
            ),
            onInterlineadoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoInterlineado: v),
            ),
            onTrackingChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(textoTracking: v),
            ),
            onRotacionChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(rotacion: v),
            ),
          ),
        if (elemento.tipo == TipoElemento.mapa)
          PanelPropiedadesMapa(
            elemento: elemento,
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
            onMostrarPksChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(mapaMostrarPks: v),
            ),
            onRotacionMapaChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(mapaRotacion: v),
            ),
            onFiguraChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(mapaFigura: v),
            ),
            onOpacidadMapaChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(mapaOpacidad: v),
            ),
            onOpacidadPrediosChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(prediosOpacidad: v),
            ),
            onBordeActivoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(mapaBordeActivo: v),
            ),
            onBordeGrosorChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(mapaBordeGrosor: v),
            ),
            onBordeColorChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(mapaBordeColorHex: v),
            ),
            onEstiloClaveChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(mapaEstiloClave: v)),
            onEstiloPksChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(mapaEstiloPks: v)),
            onBordeEstiloChanged: (v) => _actualizarElemento(elemento.id, (e) => e.copyWith(mapaBordeEstilo: v)),
            onBordeOpacidadChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(mapaBordeOpacidad: v),
            ),
          ),
        if (elemento.tipo == TipoElemento.icono)
          PanelPropiedadesIcono(
            elemento: elemento,
            onIconoChanged: (nombre, etiqueta) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(
                iconoNombre: nombre,
                // Renombrar la capa solo si conservaba el nombre automático.
                nombreCapa: e.nombreCapa ==
                        iconosComposicion
                            .where((i) => i.$1 == e.iconoNombre)
                            .map((i) => i.$2)
                            .firstOrNull
                    ? etiqueta
                    : null,
              ),
            ),
            onColorChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(iconoColorHex: v),
            ),
          ),
        if (elemento.tipo == TipoElemento.norte)
          PanelPropiedadesNorte(
            elemento: elemento,
            mapasDisponibles: _hojaActiva.elementos
                .where((e) => e.tipo == TipoElemento.mapa)
                .toList(),
            onChanged: (f) => _actualizarElemento(elemento.id, f),
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
            onChanged: (f) => _actualizarElemento(elemento.id, f),
          ),
        if (elemento.tipo == TipoElemento.simbologia)
          PanelPropiedadesSimbologia(
            elemento: elemento,
            onTipoChanged: (v) => _actualizarElemento(
              elemento.id,
              (e) => e.copyWith(simbologiaTipo: v),
            ),
          ),
        if (elemento.tipo == TipoElemento.tabla)
          PanelPropiedadesTabla(
            key: ValueKey(elemento.id),
            elemento: elemento,
            seleccion: elemento.id == _tablaSelId ? _tablaSeleccion : const {},
            onChanged: (f) => _actualizarElemento(elemento.id, f),
            onSeleccionChanged: (s) => setState(() {
              _tablaSelId = elemento.id;
              _tablaSel = s;
              _tablaAncla = s.isEmpty ? null : s.first;
              _tablaEditandoCelda = null;
            }),
          ),
        if (elemento.tipo == TipoElemento.grafica)
          PanelPropiedadesGrafica(
            elemento: elemento,
            proyectos: ref.watch(proyectosCodigosProvider),
            segmentos: _segmentosGraficaDe(elemento.graficaProyecto, _resolverDatosGraficaActual()),
            onChanged: (f) => _actualizarElemento(elemento.id, f),
            onDatosChanged: () => _marcarAjusteGrafica(elemento.id),
            onAjustarAlContenido: () => _marcarAjusteGrafica(elemento.id),
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
      ..color = const Color(0xFFC2C6CE)
      ..strokeWidth = 1.0;
    final textStyle = const TextStyle(color: Color(0xFFAEB2B9), fontSize: 8);

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


/// Mantiene el texto de la hoja en oscuro aunque la app esté en tema
/// oscuro: la hoja conserva su propio color (blanco por defecto).
class _TemaHoja extends StatelessWidget {
  const _TemaHoja({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    if (base.brightness != Brightness.dark) return child;
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.black),
        child: child,
      ),
    );
  }
}
