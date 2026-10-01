import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../estructura/models/proyecto_item.dart';
import '../../../predios/models/predio.dart';
import '../../models/elemento_composicion.dart';
import '../../utils/color_hex.dart';
import 'elemento_contenido.dart';
import 'mapa_viewport_widget.dart';
import 'marco_clipper.dart';

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
  late TextEditingController _textoCtrl;
  (double, double, double)? _mapaPendiente;

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
      if (_editandoMapa) _confirmarMapa();
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
    Offset.zero,
    Offset(widget.hojaAnchoMm, 0),
    Offset(0, widget.hojaAltoMm),
    Offset(widget.hojaAnchoMm, widget.hojaAltoMm),
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

  void _redimensionarDesdeEsquina(String esquina, Offset deltaPx) {
    final g = _geometria();
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
    final r = _snapRedimensionar(esquina, x, y, w, h);
    x = r.x;
    y = r.y;
    w = r.w;
    h = r.h;
    const minSize = 8.0;
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

  void _confirmarMapa() {
    setState(() => _editandoMapa = false);
    final pendiente = _mapaPendiente;
    if (pendiente != null) {
      widget.onMapaChanged?.call(pendiente.$1, pendiente.$2, pendiente.$3);
    }
  }

  bool get _interaccionBoxBloqueada =>
      widget.elemento.bloqueado ||
      (_editandoMapa && widget.elemento.tipo == TipoElemento.mapa);

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
                      onDoubleTap: widget.elemento.tipo == TipoElemento.mapa
                          ? () {
                              widget.onSelect();
                              setState(() {
                                _editandoMapa = true;
                                _mapaPendiente = null;
                              });
                            }
                          : null,
                      onPanStart: _interaccionBoxBloqueada
                          ? null
                          : (_) => widget.onSelect(),
                      onPanUpdate: _interaccionBoxBloqueada
                          ? null
                          : (details) => _moverPor(details.delta),
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
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
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
    if (e.tipo == TipoElemento.mapa) {
      final figuraMapa = e.mapaFigura ?? FormaMarco.cuadrada;
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: MarcoClipper(figuraMapa),
            child: MapaViewportWidget(
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
                  figura: figuraMapa,
                  color: (colorFromHex(e.mapaBordeColorHex) ?? Colors.black)
                      .withValues(alpha: e.mapaBordeOpacidad ?? 1),
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
    Widget manija(String esquina, double left, double top, MouseCursor cursor) {
      return Positioned(
        left: left - tam / 2,
        top: top - tam / 2,
        child: MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {
              _redimensionando = true;
              widget.onSelect();
            },
            onPanUpdate: (details) =>
                _redimensionarDesdeEsquina(esquina, details.delta),
            onPanEnd: (_) {
              _redimensionando = false;
              _reportarSnap(null);
            },
            onPanCancel: () {
              _redimensionando = false;
              _reportarSnap(null);
            },
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
