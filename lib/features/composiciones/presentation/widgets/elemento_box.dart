import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../estructura/models/proyecto_item.dart';
import '../../../predios/models/predio.dart';
import '../../models/elemento_composicion.dart';
import '../../utils/color_hex.dart';
import 'elemento_contenido.dart';
import 'mapa_viewport_widget.dart';

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
    required this.seleccionado,
    required this.onSelect,
    required this.onGeometriaChanged,
    this.onTextoChanged,
    this.onMapaChanged,
    this.predios = const [],
    this.hojaElementos = const [],
    this.proyectoItem,
    this.importedFeatures = const [],
  });
  final List<Map<String, dynamic>> importedFeatures;

  final ElementoComposicion elemento;
  final double scale;
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
    widget.onGeometriaChanged(
      g.x + deltaPx.dx / widget.scale,
      g.y + deltaPx.dy / widget.scale,
      g.width,
      g.height,
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
    const minSize = 8.0;
    if (w < minSize || h < minSize) return;
    widget.onGeometriaChanged(x, y, w, h);
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
        opacity: e.visible ? 1 : 0.35,
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
                          if (!_interaccionBoxBloqueada && !_redimensionando) {
                            _moverPor(event.delta);
                          }
                        }
                      : null,
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
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
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
      return MapaViewportWidget(
        lat: e.mapaLat ?? 20.72,
        lng: e.mapaLng ?? -100.35,
        zoom: e.mapaZoom ?? 12,
        predios: widget.predios,
        importedFeatures: widget.importedFeatures,
        interactivo: _editandoMapa,
        onPosicionCambiada: (lat, lng, zoom) =>
            _mapaPendiente = (lat, lng, zoom),
        baseLayer: e.mapaBaseLayer ?? 'estandar',
        mostrarEtiquetasClave: e.mapaMostrarClaves ?? false,
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
            onPanEnd: (_) => _redimensionando = false,
            onPanCancel: () => _redimensionando = false,
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
