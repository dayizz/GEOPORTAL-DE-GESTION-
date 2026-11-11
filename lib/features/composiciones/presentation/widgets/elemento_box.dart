import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../estructura/models/proyecto_item.dart';
import '../../../predios/models/predio.dart';
import '../../models/elemento_composicion.dart';
import '../../utils/color_hex.dart';
import 'elemento_contenido.dart';
import 'mapa_viewport_widget.dart';
import 'marco_clipper.dart';
import 'tabla_widget.dart';
import '../../utils/datos_grafica.dart';

/// Geometría de un elemento en mm (mismas unidades que el modelo).
typedef _GeometriaMm = ({double x, double y, double width, double height});

/// Envoltorio posicionado/seleccionable/arrastrable/redimensionable para
/// un [ElementoComposicion] dentro del lienzo. El lienzo (widget padre)
/// es responsable de convertir mm <-> px mediante [scale] (px por mm).
class ElementoBox extends StatefulWidget {
  const ElementoBox({
    super.key,
    required this.elemento,
    required this.scale,
    required this.hojaAnchoMm,
    required this.hojaAltoMm,
    required this.seleccionado,
    required this.onSelect,
    required this.onGeometriaChanged,
    this.onTextoChanged,
    this.onMapaChanged,
    this.predios = const [],
    this.hojaElementos = const [],
    this.proyectoItem,
    this.importedFeatures = const [],
    this.pksFeatures = const [],
    this.onSnapIndicador,
    this.margenMm = 0,
    this.margenesMm,
    this.datosGrafica,
    this.onAspectoGrafica,
    this.tablaSeleccion = const {},
    this.tablaEditando,
    this.onCeldaTap,
    this.onCeldaChanged,
    this.onTablaEdicionTerminada,
    this.onTablaRedimensionar,
    this.onCeldaMenu,
    this.onMenu,
  });
  final List<Map<String, dynamic>> importedFeatures;

  /// Features GeoJSON de puntos PKS importados en la sesión (ver
  /// `pksPointFeaturesProvider`), solo relevante para [TipoElemento.mapa].
  final List<Map<String, dynamic>> pksFeatures;

  final ElementoComposicion elemento;
  final double scale;

  /// Dimensiones de la hoja activa en mm, usadas por el snap tipo OSNAP
  /// (ver [_ElementoBoxState._aplicarSnap]): esquinas y punto medio
  /// horizontal/vertical de la hoja como referencias de alineación.
  final double hojaAnchoMm;
  final double hojaAltoMm;
  final double margenMm;
  final EdgeInsets? margenesMm;

  /// Reporta (en px del lienzo) el punto de referencia sobre el que se
  /// "imantó" el elemento durante un arrastre/redimensionado -null cuando
  /// no hay snap activo en ese instante-, para que el lienzo dibuje el
  /// indicador visual momentáneo (ver `SnapIndicator`).
  final ValueChanged<Offset?>? onSnapIndicador;

  final bool seleccionado;
  final VoidCallback onSelect;
  final void Function(double xMm, double yMm, double wMm, double hMm)
  onGeometriaChanged;
  final ValueChanged<String>? onTextoChanged;

  /// Solo para [TipoElemento.grafica] (ver `buildElementoContenidoEstatico`).
  final ResolverDatosGrafica? datosGrafica;
  final ValueChanged<double>? onAspectoGrafica;

  /// Solo para [TipoElemento.tabla]: celdas seleccionadas y en edición
  /// (el estado vive en el editor porque el panel de propiedades lo usa).
  /// [onCeldaTap] recibe `doble: true` en un doble clic sobre la celda.
  final Set<CeldaTabla> tablaSeleccion;
  final CeldaTabla? tablaEditando;
  final void Function(CeldaTabla celda, {required bool doble})? onCeldaTap;
  final void Function(CeldaTabla celda, String texto)? onCeldaChanged;
  final VoidCallback? onTablaEdicionTerminada;
  /// Arrastre de los divisores entre columnas/filas de la tabla.
  final ValueChanged<ElementoComposicion Function(ElementoComposicion)>? onTablaRedimensionar;
  final void Function(CeldaTabla celda, Offset posicion)? onCeldaMenu;
  /// Clic derecho sobre el elemento, con la posición global del puntero.
  final ValueChanged<Offset>? onMenu;
  final void Function(double lat, double lng, double zoom)? onMapaChanged;
  final List<Predio> predios;

  /// Todos los elementos de la hoja activa (para [TipoElemento.escala],
  /// que necesita ubicar el elemento de mapa asociado).
  final List<ElementoComposicion> hojaElementos;

  /// Solo se usa para [TipoElemento.grafica] con [TipoGrafica.cadenamiento].
  final ProyectoItem? proyectoItem;

  @override
  State<ElementoBox> createState() => _ElementoBoxState();
}

class _ElementoBoxState extends State<ElementoBox> {
  bool _editandoTexto = false;
  bool _editandoMapa = false;
  bool _redimensionando = false;
  // Geometría (sin imán) acumulada durante un redimensionado: varios
  // movimientos del puntero pueden llegar antes de que el editor
  // reconstruya con el tamaño nuevo, y partir de `widget.elemento` los
  // perdería.
  _GeometriaMm? _geoRedimension;
  late TextEditingController _textoCtrl;
  (double, double, double)? _mapaPendiente;
  // Doble clic en una celda de tabla, detectado a mano: un `onDoubleTap`
  // retrasaría cada clic simple (selección) mientras espera el segundo.
  CeldaTabla? _ultimaCeldaTocada;
  DateTime? _ultimoToqueCelda;

  void _tocarCelda(CeldaTabla celda) {
    final ahora = DateTime.now();
    final doble = _ultimaCeldaTocada == celda &&
        _ultimoToqueCelda != null &&
        ahora.difference(_ultimoToqueCelda!) < kDoubleTapTimeout;
    _ultimaCeldaTocada = doble ? null : celda;
    _ultimoToqueCelda = doble ? null : ahora;
    widget.onCeldaTap?.call(celda, doble: doble);
  }

  @override
  void initState() {
    super.initState();
    _textoCtrl = TextEditingController(
      text: widget.elemento.textoContenido ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant ElementoBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editandoTexto &&
        widget.elemento.textoContenido != oldWidget.elemento.textoContenido) {
      _textoCtrl.text = widget.elemento.textoContenido ?? '';
    }
    if (!widget.seleccionado && oldWidget.seleccionado) {
      // Deseleccionar desde afuera (p.ej. click en el fondo del lienzo)
      // también cierra cualquier modo de edición en curso.
      // didUpdateWidget corre durante el build del editor: notificar ahí la
      // posición del mapa hacía setState en el padre en plena construcción
      // ("setState() called during build"), así que se difiere al final
      // del frame.
      if (_editandoMapa) {
        _editandoMapa = false;
        final pendiente = _mapaPendiente;
        if (pendiente != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onMapaChanged?.call(pendiente.$1, pendiente.$2, pendiente.$3);
          });
        }
      }
      if (_editandoTexto) setState(() => _editandoTexto = false);
    }
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    super.dispose();
  }

  _GeometriaMm _geometria() => (
    x: widget.elemento.x,
    y: widget.elemento.y,
    width: widget.elemento.width,
    height: widget.elemento.height,
  );

  void _moverPor(Offset deltaPx) {
    final g = _geometria();
    final r = _snapMover(
      g.x + deltaPx.dx / widget.scale,
      g.y + deltaPx.dy / widget.scale,
      g.width,
      g.height,
    );
    widget.onGeometriaChanged(r.x, r.y, g.width, g.height);
    _reportarSnap(r.snapMm);
  }

  /// OSNAP (referencia a objetos): umbral de imantación, en px de
  /// pantalla (convertido a mm vía [ElementoBox.scale] en cada cálculo,
  /// para que el umbral "se sienta" igual sin importar el zoom del
  /// lienzo).
  static const _snapUmbralPx = 8.0;

  List<Offset> get _esquinasHoja => [
    Offset(widget.margenesMm?.left ?? widget.margenMm, widget.margenesMm?.top ?? widget.margenMm),
    Offset(widget.hojaAnchoMm - (widget.margenesMm?.right ?? widget.margenMm), widget.margenesMm?.top ?? widget.margenMm),
    Offset(widget.margenesMm?.left ?? widget.margenMm, widget.hojaAltoMm - (widget.margenesMm?.bottom ?? widget.margenMm)),
    Offset(widget.hojaAnchoMm - (widget.margenesMm?.right ?? widget.margenMm), widget.hojaAltoMm - (widget.margenesMm?.bottom ?? widget.margenMm)),
  ];

  /// Al mover un elemento, si alguna de sus 4 esquinas queda a menos del
  /// umbral de una esquina de la hoja, ese punto "imanta" exactamente a
  /// la esquina. Si no hubo snap de esquina, el centro del elemento se
  /// imanta por separado a la línea media horizontal y/o vertical de la
  /// hoja cuando queda cerca de ellas. [snapMm] (para el indicador
  /// visual) es el punto de referencia exacto sobre el que se imantó.
  ({double x, double y, Offset? snapMm}) _snapMover(
    double x,
    double y,
    double w,
    double h,
  ) {
    final umbralMm = _snapUmbralPx / widget.scale;
    final esquinasElemento = [
      Offset(x, y),
      Offset(x + w, y),
      Offset(x, y + h),
      Offset(x + w, y + h),
    ];

    Offset? mejorAjuste;
    Offset? mejorRef;
    var mejorDist = umbralMm;
    for (final ee in esquinasElemento) {
      for (final eh in _esquinasHoja) {
        final dist = (eh - ee).distance;
        if (dist < mejorDist) {
          mejorDist = dist;
          mejorAjuste = eh - ee;
          mejorRef = eh;
        }
      }
    }
    if (mejorAjuste != null) {
      return (x: x + mejorAjuste.dx, y: y + mejorAjuste.dy, snapMm: mejorRef);
    }

    var snappedX = x;
    var snappedY = y;
    final medioX = widget.hojaAnchoMm / 2;
    final medioY = widget.hojaAltoMm / 2;
    final snapX = (x + w / 2 - medioX).abs() < umbralMm;
    final snapY = (y + h / 2 - medioY).abs() < umbralMm;
    if (snapX) snappedX = medioX - w / 2;
    if (snapY) snappedY = medioY - h / 2;
    if (!snapX && !snapY) {
      return (x: snappedX, y: snappedY, snapMm: null);
    }
    return (
      x: snappedX,
      y: snappedY,
      snapMm: Offset(
        snapX ? medioX : snappedX + w / 2,
        snapY ? medioY : snappedY + h / 2,
      ),
    );
  }

  /// La escala ocupa solo lo que mide su barra: tras dibujarse, el
  /// recuadro se ajusta a ella (no durante un redimensionado, para no
  /// pelear con la manija; al soltarla se vuelve a ajustar).
  void _ajustarAEscala(Size tamanoPx) {
    final e = widget.elemento;
    if (!mounted || _redimensionando || e.bloqueado) return;
    final w = tamanoPx.width / widget.scale;
    final h = tamanoPx.height / widget.scale;
    if ((w - e.width).abs() < 0.3 && (h - e.height).abs() < 0.3) return;
    widget.onGeometriaChanged(e.x, e.y, w, h);
  }

  void _redimensionarDesdeEsquina(String esquina, Offset deltaPx) {
    final g = _geoRedimension ?? _geometria();
    final dxMm = deltaPx.dx / widget.scale;
    final dyMm = deltaPx.dy / widget.scale;
    var x = g.x, y = g.y, w = g.width, h = g.height;
    switch (esquina) {
      case 'tl':
        x += dxMm;
        y += dyMm;
        w -= dxMm;
        h -= dyMm;
        break;
      case 'tr':
        y += dyMm;
        w += dxMm;
        h -= dyMm;
        break;
      case 'bl':
        x += dxMm;
        w -= dxMm;
        h += dyMm;
        break;
      case 'br':
        w += dxMm;
        h += dyMm;
        break;
    }
    // La escala se ajusta sola a su barra, que mide menos de 8 mm de alto.
    final minSize = widget.elemento.tipo == TipoElemento.escala ? 1.0 : 8.0;
    if (w < minSize || h < minSize) return;
    _geoRedimension = (x: x, y: y, width: w, height: h);
    final r = _snapRedimensionar(esquina, x, y, w, h);
    x = r.x;
    y = r.y;
    w = r.w;
    h = r.h;
    if (w < minSize || h < minSize) return;
    widget.onGeometriaChanged(x, y, w, h);
    _reportarSnap(r.snapMm);
  }

  /// Igual que [_snapMover] pero para redimensionado: solo la esquina
  /// activa ([esquina]) se prueba contra las esquinas de la hoja (imán) o,
  /// si no hubo snap de esquina, contra las líneas medias (cada eje por
  /// separado) -no hay "centro" que imantar al estirar, es ese punto el
  /// que se está arrastrando-.
  ({double x, double y, double w, double h, Offset? snapMm}) _snapRedimensionar(
    String esquina,
    double x,
    double y,
    double w,
    double h,
  ) {
    final umbralMm = _snapUmbralPx / widget.scale;
    final puntoActual = switch (esquina) {
      'tl' => Offset(x, y),
      'tr' => Offset(x + w, y),
      'bl' => Offset(x, y + h),
      _ => Offset(x + w, y + h),
    };

    Offset? destino;
    var mejorDist = umbralMm;
    for (final eh in _esquinasHoja) {
      final dist = (eh - puntoActual).distance;
      if (dist < mejorDist) {
        mejorDist = dist;
        destino = eh;
      }
    }
    if (destino == null) {
      final medioX = widget.hojaAnchoMm / 2;
      final medioY = widget.hojaAltoMm / 2;
      final snapX = (puntoActual.dx - medioX).abs() < umbralMm;
      final snapY = (puntoActual.dy - medioY).abs() < umbralMm;
      if (snapX || snapY) {
        destino = Offset(
          snapX ? medioX : puntoActual.dx,
          snapY ? medioY : puntoActual.dy,
        );
      }
    }
    if (destino == null) {
      return (x: x, y: y, w: w, h: h, snapMm: null);
    }

    final dx = destino.dx - puntoActual.dx;
    final dy = destino.dy - puntoActual.dy;
    var nx = x, ny = y, nw = w, nh = h;
    switch (esquina) {
      case 'tl':
        nx += dx;
        ny += dy;
        nw -= dx;
        nh -= dy;
        break;
      case 'tr':
        ny += dy;
        nw += dx;
        nh -= dy;
        break;
      case 'bl':
        nx += dx;
        nw -= dx;
        nh += dy;
        break;
      case 'br':
        nw += dx;
        nh += dy;
        break;
    }
    return (x: nx, y: ny, w: nw, h: nh, snapMm: destino);
  }

  void _reportarSnap(Offset? puntoMm) {
    widget.onSnapIndicador?.call(
      puntoMm == null ? null : puntoMm * widget.scale,
    );
  }

  bool get _interaccionBoxBloqueada =>
      widget.elemento.bloqueado ||
      (_editandoMapa && widget.elemento.tipo == TipoElemento.mapa) ||
      // Mientras se escribe en una celda, arrastrar selecciona texto en vez
      // de mover la tabla.
      widget.tablaEditando != null;

  @override
  Widget build(BuildContext context) {
    final e = widget.elemento;
    final wPx = e.width * widget.scale;
    final hPx = e.height * widget.scale;

    return Positioned(
      left: e.x * widget.scale,
      top: e.y * widget.scale,
      width: wPx,
      height: hPx,
      child: Opacity(
        // Un elemento oculto (`visible: false`, toggle desde el panel de
        // capas) se oculta por completo del lienzo -no solo atenuado-,
        // igual que se ve en la exportación (ver `if (e.visible)` en
        // `HojaExportWidget`). Sigue pudiendo reseleccionarse desde el
        // panel de capas (que no depende del hit-testing del lienzo) para
        // reactivar su visibilidad.
        opacity: e.visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !e.visible,
          // El botón "Listo" (solo visible en modo edición de mapa) se
          // pinta en un `Stack` propio, FUERA del `GestureDetector` de
          // abajo: cuando ese `GestureDetector` tiene `onDoubleTap`
          // registrado, todo tap dentro de su subárbol -incluido un botón
          // hijo- queda sujeto a la espera de desambiguación doble-tap y
          // pierde el toque contra el pan del mapa. Como hermano
          // independiente, su propio `InkWell` resuelve el tap de
          // inmediato, sin competir por ese arbitraje.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.rotate(
                angle: e.rotacion * 3.1415926535 / 180,
                child: MouseRegion(
                  cursor: _interaccionBoxBloqueada
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.move,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => widget.onSelect(),
                    onPointerMove: widget.elemento.tipo == TipoElemento.mapa
                        ? (event) {
                            if (!_interaccionBoxBloqueada &&
                                !_redimensionando) {
                              _moverPor(event.delta);
                            }
                          }
                        : null,
                    onPointerUp: (_) => _reportarSnap(null),
                    onPointerCancel: (_) => _reportarSnap(null),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onSelect,
                      onSecondaryTapDown: widget.onMenu == null
                          ? null
                          : (d) => widget.onMenu!(d.globalPosition),
                      onDoubleTap: widget.elemento.tipo == TipoElemento.mapa
                          ? () {
                              widget.onSelect();
                              setState(() {
                                _editandoMapa = true;
                                _mapaPendiente = null;
                              });
                            }
                          : null,
                      onPanStart: _interaccionBoxBloqueada || e.tipo == TipoElemento.mapa
                          ? null
                          : (_) => widget.onSelect(),
                      // Arrastrar una manija también llega aquí como pan: sin
                      // este chequeo, mover el elemento (con el tamaño
                      // anterior) pisaba en el mismo evento el redimensionado.
                      onPanUpdate: _interaccionBoxBloqueada || e.tipo == TipoElemento.mapa
                          ? null
                          : (details) {
                              if (!_redimensionando) _moverPor(details.delta);
                            },
                      onPanEnd: (_) => _reportarSnap(null),
                      onPanCancel: () => _reportarSnap(null),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // `Positioned.fill`: sin esto, este `Container`
                          // -hijo no-posicionado del `Stack`- se ajusta a
                          // su contenido (p.ej. un `Text` corto) en vez de
                          // llenar el recuadro, y el redimensionado manual
                          // deja de verse (el borde de selección "no se
                          // estira" aunque el modelo sí cambió de tamaño).
                          //
                          // El borde de selección va en `foregroundDecoration`
                          // (encima, sin restar espacio): como `decoration`
                          // encogía 3 px el contenido, la escala -que ajusta
                          // el recuadro a lo que mide- dejaba de caber,
                          // elegía una distancia menor y se encogía sin fin.
                          Positioned.fill(
                            child: Container(
                              foregroundDecoration: BoxDecoration(
                                border: widget.seleccionado
                                    ? Border.all(
                                        color: Colors.blueAccent,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: _buildContenido(e),
                            ),
                          ),
                          if (widget.seleccionado &&
                              !e.bloqueado &&
                              !_editandoMapa)
                            ..._buildManijas(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_editandoMapa) _buildBotonListoMapa(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContenido(ElementoComposicion e) {
    if (e.tipo == TipoElemento.texto && _editandoTexto) {
      return Container(
        color: colorFromHex(e.textoColorFondoHex),
        padding: const EdgeInsets.all(4),
        alignment: Alignment.topLeft,
        child: TextField(
          controller: _textoCtrl,
          autofocus: true,
          maxLines: null,
          textAlign: textoAlignDe(e),
          style: textoEstiloDe(e),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: widget.onTextoChanged,
          onTapOutside: (_) => setState(() => _editandoTexto = false),
          onSubmitted: (_) => setState(() => _editandoTexto = false),
        ),
      );
    }
    if (e.tipo == TipoElemento.tabla && widget.onCeldaTap != null) {
      return TablaWidget(
        elemento: e,
        seleccion: widget.tablaSeleccion,
        editando: widget.tablaEditando,
        onCeldaTap: _tocarCelda,
        onCeldaChanged: widget.onCeldaChanged,
        onEdicionTerminada: widget.onTablaEdicionTerminada,
        onRedimensionar: e.bloqueado ? null : widget.onTablaRedimensionar,
        onCeldaMenu: widget.onCeldaMenu,
      );
    }
    if (e.tipo == TipoElemento.mapa) {
      final figuraMapa = e.mapaFigura ?? FormaMarco.cuadrada;
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: MarcoClipper(figuraMapa),
            child: MapaViewportWidget(
              estiloClave: e.mapaEstiloClave,
              estiloPks: e.mapaEstiloPks,
              lat: e.mapaLat ?? 20.72,
              lng: e.mapaLng ?? -100.35,
              zoom: e.mapaZoom ?? 12,
              predios: widget.predios,
              importedFeatures: widget.importedFeatures,
              pksFeatures: widget.pksFeatures,
              interactivo: _editandoMapa,
              onPosicionCambiada: (lat, lng, zoom) =>
                  _mapaPendiente = (lat, lng, zoom),
              baseLayer: e.mapaBaseLayer ?? 'estandar',
              mostrarEtiquetasClave: e.mapaMostrarClaves ?? false,
              mostrarPks: e.mapaMostrarPks ?? false,
              rotacion: e.mapaRotacion ?? 0,
              opacidadMapa: e.mapaOpacidad ?? 1,
              opacidadPredios: e.prediosOpacidad ?? 0.35,
            ),
          ),
          if (e.mapaBordeActivo ?? false)
            IgnorePointer(
              child: CustomPaint(
                painter: MarcoBorderPainter(
                  estilo: e.mapaBordeEstilo,
                  figura: figuraMapa,
                  color: aplicarOpacidad(
                      colorFromHex(e.mapaBordeColorHex) ?? Colors.black,
                      e.mapaBordeOpacidad ?? 1),
                  grosor: e.mapaBordeGrosor ?? 2,
                ),
              ),
            ),
        ],
      );
    }
    return buildElementoContenidoEstatico(
      e,
      predios: widget.predios,
      hojaElementos: widget.hojaElementos,
      scale: widget.scale,
      proyectoItem: widget.proyectoItem,
      datosGrafica: widget.datosGrafica,
      onAspectoGrafica: widget.onAspectoGrafica,
      onTamanoEscala: e.tipo == TipoElemento.escala ? _ajustarAEscala : null,
    );
  }

  /// Indicador de que el mapa está en modo edición (arriba del recuadro,
  /// fuera de sus límites gracias a `clipBehavior: Clip.none`). Es
  /// puramente informativo -no interactivo-: confirmar se hace tocando
  /// fuera del recuadro (ver `didUpdateWidget`, que llama a
  /// `_confirmarMapa` cuando el elemento se deselecciona). Un botón
  /// superpuesto aquí perdía sistemáticamente el toque contra el propio
  /// `FlutterMap` interactivo (lo capta como un pan/gesto propio en vez
  /// de como un tap en el botón), así que se optó por reusar el gesto de
  /// deselección, que ya es confiable para salir del modo edición de
  /// texto.
  Widget _buildBotonListoMapa() {
    return Positioned(
      right: 0,
      top: -30,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Toca fuera para confirmar',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildManijas() {
    const tam = 10.0;
    // 'tl'/'br' se estiran en diagonal \ (resizeUpLeftDownRight); 'tr'/'bl'
    // en diagonal / (resizeUpRightDownLeft), indicando con el cursor la
    // dirección real en la que cada esquina redimensiona.
    // Solo la parte de la manija dentro del recuadro recibe el puntero
    // (fuera de él no hay hit-testing), así que la zona sensible es un
    // cuadro de [zona] px hacia adentro de la esquina y el círculo se
    // dibuja centrado en la esquina, desbordando hacia afuera.
    const zona = 16.0;
    Widget manija(String esquina, double left, double top, MouseCursor cursor) {
      final derecha = left > 0;
      final abajo = top > 0;
      return Positioned(
        left: derecha ? left - zona : 0,
        top: abajo ? top - zona : 0,
        child: MouseRegion(
          cursor: cursor,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {
              _redimensionando = true;
              _geoRedimension = null;
              widget.onSelect();
            },
            onPointerMove: (event) => _redimensionarDesdeEsquina(esquina, event.delta),
            onPointerUp: (_) {
              // El `setState` vuelve a dibujar el contenido, para que una
              // escala se ajuste al tamaño soltado.
              setState(() => _redimensionando = false);
              _geoRedimension = null;
              _reportarSnap(null);
            },
            onPointerCancel: (_) {
              _redimensionando = false;
              _geoRedimension = null;
              _reportarSnap(null);
            },
            child: SizedBox(
              width: zona,
              height: zona,
              child: OverflowBox(
                minWidth: 0,
                minHeight: 0,
                maxWidth: tam,
                maxHeight: tam,
                alignment: Alignment(derecha ? 1 : -1, abajo ? 1 : -1),
                child: Transform.translate(
                  offset: Offset(derecha ? tam / 2 : -tam / 2, abajo ? tam / 2 : -tam / 2),
                  child: Container(
                    width: tam,
                    height: tam,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.blueAccent, width: 1.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final w = widget.elemento.width * widget.scale;
    final h = widget.elemento.height * widget.scale;
    return [
      manija('tl', 0, 0, SystemMouseCursors.resizeUpLeftDownRight),
      manija('tr', w, 0, SystemMouseCursors.resizeUpRightDownLeft),
      manija('bl', 0, h, SystemMouseCursors.resizeUpRightDownLeft),
      manija('br', w, h, SystemMouseCursors.resizeUpLeftDownRight),
    ];
  }
}
