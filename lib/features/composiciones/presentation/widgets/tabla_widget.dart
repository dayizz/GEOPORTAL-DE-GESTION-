import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/elemento_composicion.dart';
import '../../utils/color_hex.dart';
import '../../utils/tabla_ops.dart';
import 'shape_painter.dart';

/// Celda de tabla como (fila, columna).
typedef CeldaTabla = (int, int);

/// px de diseño por mm con los que se arma la tabla antes de escalarla a
/// su recuadro; así el texto guarda la misma proporción en el editor (a
/// cualquier zoom) y al exportar.
const _pxPorMm = 2.5;

/// Tabla de un elemento [TipoElemento.tabla]: llena todo su recuadro,
/// repartiendo el ancho/alto según `tablaAnchosColumna`/`tablaAltosFila`.
/// Sin callbacks es de solo lectura (exportación); con [onCeldaTap] las
/// celdas se pueden seleccionar y la celda [editando] se muestra como
/// campo de texto. Con [onRedimensionar], los divisores entre columnas y
/// filas se pueden arrastrar.
class TablaWidget extends StatefulWidget {
  const TablaWidget({
    super.key,
    required this.elemento,
    this.seleccion = const {},
    this.editando,
    this.onCeldaTap,
    this.onCeldaChanged,
    this.onEdicionTerminada,
    this.onRedimensionar,
    this.onCeldaMenu,
  });
  final ElementoComposicion elemento;
  final Set<CeldaTabla> seleccion;
  final CeldaTabla? editando;
  final ValueChanged<CeldaTabla>? onCeldaTap;
  final void Function(CeldaTabla celda, String texto)? onCeldaChanged;
  final VoidCallback? onEdicionTerminada;
  final ValueChanged<ElementoComposicion Function(ElementoComposicion)>? onRedimensionar;
  /// Clic derecho en una celda, con la posición global del puntero.
  final void Function(CeldaTabla celda, Offset posicion)? onCeldaMenu;

  @override
  State<TablaWidget> createState() => _TablaWidgetState();
}

class _TablaWidgetState extends State<TablaWidget> {
  final _claveLienzo = GlobalKey();
  // Arrastre de una línea: la tabla y la posición (px de diseño) al
  // empezar, para que el cambio no acumule errores de redondeo. La
  // conversión a coordenadas locales se fija al empezar porque arrastrar
  // el borde izquierdo/superior mueve la propia tabla.
  ElementoComposicion? _elementoInicio;
  Matrix4? _aLocalInicio;
  Offset _inicioArrastre = Offset.zero;

  Offset _local(Offset global) => MatrixUtils.transformPoint(_aLocalInicio!, global);

  @override
  Widget build(BuildContext context) {
    final e = widget.elemento;
    final celdas = e.tablaCeldas;
    if (celdas.isEmpty) return const SizedBox.shrink();
    final columnas = columnasTabla(celdas);
    if (columnas == 0) return const SizedBox.shrink();
    final borde = _BordeTabla(
      estilo: e.tablaBordeEstilo ?? EstiloLinea.continua,
      color: colorFromHex(e.tablaBordeColorHex) ?? const Color(0xFF757575),
      grosor: e.tablaBordeGrosor ?? 1,
    );
    final anchos = [for (final mm in anchosColumnaMm(e)) mm * _pxPorMm];
    final altos = [for (final mm in altosFilaMm(e)) mm * _pxPorMm];
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        key: _claveLienzo,
        width: math.max(1, e.width * _pxPorMm),
        height: math.max(1, e.height * _pxPorMm),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                for (var i = 0; i < celdas.length; i++)
                  SizedBox(
                    height: altos[i],
                    child: Row(
                      children: [
                        for (var j = 0; j < columnas; j++)
                          SizedBox(
                            width: anchos[j],
                            child: _celda(
                              i, j,
                              j < celdas[i].length ? celdas[i][j] : '',
                              borde,
                              ultimaFila: i == celdas.length - 1,
                              ultimaColumna: j == columnas - 1,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            if (widget.onRedimensionar != null && widget.editando == null) ...[
              // -1 es el borde izquierdo/superior y n-1 el derecho/inferior.
              for (var j = -1; j < columnas; j++)
                _divisor(anchos.take(j + 1).fold(0.0, (a, b) => a + b), j, columnas, vertical: true),
              for (var i = -1; i < celdas.length; i++)
                _divisor(altos.take(i + 1).fold(0.0, (a, b) => a + b), i, celdas.length, vertical: false),
            ],
          ],
        ),
      ),
    );
  }

  /// Zona arrastrable sobre la línea que sigue a la columna/fila [indice]
  /// (de [total]). Una línea interior pasa medida de una columna/fila a la
  /// vecina sin cambiar el tamaño de la tabla; las del perímetro cambian
  /// la primera/última columna o fila y la tabla crece o se encoge (el
  /// borde izquierdo/superior también la desplaza).
  Widget _divisor(double posicion, int indice, int total, {required bool vertical}) {
    const grosor = 8.0;
    final inicio = indice < 0;
    final fin = indice == total - 1;
    // Las del perímetro quedan por dentro del recuadro: fuera de él no
    // recibirían el puntero.
    final desde = inicio ? 0.0 : fin ? posicion - grosor : posicion - grosor / 2;
    return Positioned(
      left: vertical ? desde : 0,
      top: vertical ? 0 : desde,
      width: vertical ? grosor : null,
      height: vertical ? null : grosor,
      right: vertical ? null : 0,
      bottom: vertical ? 0 : null,
      child: MouseRegion(
        cursor: vertical ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            final caja = _claveLienzo.currentContext!.findRenderObject()! as RenderBox;
            _aLocalInicio = Matrix4.tryInvert(caja.getTransformTo(null));
            if (_aLocalInicio == null) return;
            _elementoInicio = widget.elemento;
            _inicioArrastre = _local(d.globalPosition);
          },
          onPanUpdate: (d) {
            final e0 = _elementoInicio;
            if (e0 == null) return;
            final actual = _local(d.globalPosition);
            final delta = (vertical ? actual.dx - _inicioArrastre.dx : actual.dy - _inicioArrastre.dy) / _pxPorMm;
            final tamanos = vertical ? anchosColumnaMm(e0) : altosFilaMm(e0);
            if (tamanos.length != total) return;
            if (inicio) {
              final primero = math.max(tablaMinimoMm, tamanos.first - delta);
              final movido = tamanos.first - primero;
              tamanos[0] = primero;
              widget.onRedimensionar!((e) => vertical
                  ? e.copyWith(tablaAnchosColumna: tamanos, x: e0.x + movido, width: e0.width - movido)
                  : e.copyWith(tablaAltosFila: tamanos, y: e0.y + movido, height: e0.height - movido));
            } else if (fin) {
              tamanos[indice] = math.max(tablaMinimoMm, tamanos[indice] + delta);
              final suma = tamanos.reduce((a, b) => a + b);
              widget.onRedimensionar!((e) => vertical
                  ? e.copyWith(tablaAnchosColumna: tamanos, width: suma)
                  : e.copyWith(tablaAltosFila: tamanos, height: suma));
            } else {
              final a = tamanos[indice];
              final b = tamanos[indice + 1];
              final paso = delta.clamp(tablaMinimoMm - a, b - tablaMinimoMm);
              tamanos[indice] = a + paso;
              tamanos[indice + 1] = b - paso;
              widget.onRedimensionar!((e) => vertical
                  ? e.copyWith(tablaAnchosColumna: tamanos)
                  : e.copyWith(tablaAltosFila: tamanos));
            }
          },
          onPanEnd: (_) => _elementoInicio = null,
          onPanCancel: () => _elementoInicio = null,
        ),
      ),
    );
  }

  Widget _celda(int i, int j, String texto, _BordeTabla borde,
      {required bool ultimaFila, required bool ultimaColumna}) {
    final estilo = EstiloCeldaTabla.efectivo(widget.elemento.tablaEstilosCelda, i, j);
    final textStyle = estiloTextoCelda(estilo);
    final textAlign = _textAlign(estilo.alineacion);
    final celda = (i, j);
    final editando = widget.editando == celda;
    final Widget contenido = editando
        ? _CeldaEditable(
            texto: texto,
            style: textStyle,
            textAlign: textAlign,
            onChanged: (v) => widget.onCeldaChanged?.call(celda, v),
            onTerminar: widget.onEdicionTerminada,
          )
        : Text(texto, style: textStyle, textAlign: textAlign);
    Widget resultado = CustomPaint(
      foregroundPainter: _CeldaPainter(
        borde: borde,
        derecha: ultimaColumna,
        abajo: ultimaFila,
        seleccionada: widget.seleccion.contains(celda),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(color: colorFromHex(estilo.rellenoHex)),
        // La alineación horizontal se aplica tanto a la caja del texto
        // como a sus líneas (`textAlign`), para que un texto corto también
        // se mueva a la derecha o al centro.
        alignment: Alignment(_alineacionX(estilo.alineacion), 0),
        child: editando ? SizedBox(width: double.infinity, child: contenido) : contenido,
      ),
    );
    if (widget.onCeldaTap != null && !editando) {
      resultado = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onCeldaTap!(celda),
        onSecondaryTapDown: widget.onCeldaMenu == null
            ? null
            : (d) => widget.onCeldaMenu!(celda, d.globalPosition),
        child: resultado,
      );
    }
    return resultado;
  }
}

double _alineacionX(AlineacionTexto? a) => switch (a ?? AlineacionTexto.izquierda) {
  AlineacionTexto.centro => 0,
  AlineacionTexto.derecha => 1,
  _ => -1,
};

/// Estilo de texto de una celda; 'Arial' es fuente del sistema (no está en
/// Google Fonts), igual que en `textoEstiloDe`.
TextStyle estiloTextoCelda(EstiloCeldaTabla estilo) {
  final base = TextStyle(
    fontSize: estilo.tamano ?? 12,
    color: colorFromHex(estilo.colorHex) ?? Colors.black,
    fontWeight: (estilo.negrita ?? false) ? FontWeight.bold : FontWeight.normal,
    fontStyle: (estilo.cursiva ?? false) ? FontStyle.italic : FontStyle.normal,
    decoration: (estilo.subrayado ?? false) ? TextDecoration.underline : null,
  );
  final fuente = estilo.fuente ?? 'Arial';
  if (fuente == 'Arial' || !GoogleFonts.asMap().containsKey(fuente)) {
    return base.copyWith(fontFamily: fuente);
  }
  return GoogleFonts.getFont(fuente, textStyle: base);
}

TextAlign _textAlign(AlineacionTexto? a) => switch (a ?? AlineacionTexto.izquierda) {
  AlineacionTexto.izquierda => TextAlign.left,
  AlineacionTexto.centro => TextAlign.center,
  AlineacionTexto.derecha => TextAlign.right,
  AlineacionTexto.justificado => TextAlign.justify,
};

class _CeldaEditable extends StatefulWidget {
  const _CeldaEditable({
    required this.texto,
    required this.style,
    required this.textAlign,
    required this.onChanged,
    this.onTerminar,
  });
  final String texto;
  final TextStyle style;
  final TextAlign textAlign;
  final ValueChanged<String> onChanged;
  final VoidCallback? onTerminar;

  @override
  State<_CeldaEditable> createState() => _CeldaEditableState();
}

class _CeldaEditableState extends State<_CeldaEditable> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.texto)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.texto.length);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    autofocus: true,
    maxLines: null,
    style: widget.style,
    textAlign: widget.textAlign,
    cursorColor: Colors.blueAccent,
    decoration: const InputDecoration(
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    ),
    onChanged: widget.onChanged,
    onTapOutside: (_) => widget.onTerminar?.call(),
  );
}

class _BordeTabla {
  const _BordeTabla({required this.estilo, required this.color, required this.grosor});
  final EstiloLinea estilo;
  final Color color;
  final double grosor;

  @override
  bool operator ==(Object other) =>
      other is _BordeTabla && other.estilo == estilo && other.color == color && other.grosor == grosor;

  @override
  int get hashCode => Object.hash(estilo, color, grosor);
}

/// Cada celda dibuja su borde superior e izquierdo (y el derecho/inferior
/// si es la última columna/fila), así cada línea de la cuadrícula se pinta
/// una sola vez y el patrón segmentado no se superpone consigo mismo.
class _CeldaPainter extends CustomPainter {
  _CeldaPainter({
    required this.borde,
    required this.derecha,
    required this.abajo,
    required this.seleccionada,
  });
  final _BordeTabla borde;
  final bool derecha;
  final bool abajo;
  final bool seleccionada;

  @override
  void paint(Canvas canvas, Size size) {
    if (borde.grosor > 0 && borde.color.a > 0) {
      final lineas = Path()
        ..moveTo(0, size.height)
        ..lineTo(0, 0)
        ..lineTo(size.width, 0);
      if (derecha) {
        lineas
          ..moveTo(size.width, 0)
          ..lineTo(size.width, size.height);
      }
      if (abajo) {
        lineas
          ..moveTo(0, size.height)
          ..lineTo(size.width, size.height);
      }
      canvas.drawPath(
        estiloLineaDe(lineas, borde.estilo, borde.grosor),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borde.grosor
          ..strokeCap = borde.estilo == EstiloLinea.continua ? StrokeCap.square : StrokeCap.round
          ..color = borde.color,
      );
    }
    if (seleccionada) {
      final r = Offset.zero & size;
      canvas.drawRect(r, Paint()..color = Colors.blueAccent.withValues(alpha: 0.12));
      canvas.drawRect(
        r.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.blueAccent,
      );
    }
  }

  @override
  bool shouldRepaint(_CeldaPainter old) =>
      old.borde != borde || old.derecha != derecha || old.abajo != abajo || old.seleccionada != seleccionada;
}
