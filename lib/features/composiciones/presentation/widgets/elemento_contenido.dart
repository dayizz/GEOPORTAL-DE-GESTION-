import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../estructura/models/proyecto_item.dart';
import '../../../predios/models/predio.dart';
import '../../models/elemento_composicion.dart';
import '../../utils/color_hex.dart';
import 'escala_grafica_widget.dart';
import 'grafica_widget.dart';
import 'mapa_viewport_widget.dart';
import 'marco_clipper.dart';
import 'norte_widget.dart';
import 'shape_painter.dart';
import 'simbologia_widget.dart';

/// Render "estático" (de solo lectura, sin interactividad) del contenido
/// visual de un [ElementoComposicion], compartido entre [ElementoBox]
/// -que lo envuelve con selección/arrastre/edición- y
/// `HojaExportWidget` -que lo usa tal cual para rasterizar al exportar-,
/// para no duplicar cómo se ve cada tipo de elemento en ambos lugares.
///
/// [predios] se usa para [TipoElemento.mapa] y [TipoElemento.grafica] (ya
/// filtrados por proyecto por quien llama; ver [MapaViewportWidget] para
/// la razón por la que no se resuelven aquí mismo vía Riverpod).
/// [hojaElementos] y [scale] solo se usan para [TipoElemento.escala] (para
/// ubicar el mapa asociado y convertir metros/px de ese mapa a metros/mm
/// de la hoja). [proyectoItem] solo se usa para [TipoElemento.grafica] con
/// [TipoGrafica.cadenamiento] (necesita el cadenamiento de Estructura).
Widget buildElementoContenidoEstatico(
  ElementoComposicion e, {
  List<Predio> predios = const [],
  List<ElementoComposicion> hojaElementos = const [],
  double scale = 1,
  ProyectoItem? proyectoItem,
}) {
  switch (e.tipo) {
    case TipoElemento.forma:
      return CustomPaint(
        size: Size.infinite,
        painter: ShapePainter(
          figuraTipo: e.figuraTipo ?? TipoFigura.rectangulo,
          colorTrazo: colorFromHex(e.colorTrazoHex) ?? Colors.black,
          grosorTrazo: e.grosorTrazo ?? 2,
          colorRelleno: colorFromHex(e.colorRellenoHex),
          estiloLinea: e.estiloLinea ?? EstiloLinea.continua,
          espaciadoLinea: e.estiloLineaEspaciado ?? 1,
          puntaTipo: e.lineaPuntaTipo ?? TipoPuntaLinea.ninguna,
          puntaTamano: e.lineaPuntaTamano ?? 10,
          puntaIzquierda: e.lineaPuntaIzquierda ?? false,
          puntaDerecha: e.lineaPuntaDerecha ?? false,
        ),
      );
    case TipoElemento.texto:
      return Container(
        color: colorFromHex(e.textoColorFondoHex),
        padding: const EdgeInsets.all(4),
        alignment: Alignment.topLeft,
        child: _buildTexto(e),
      );
    case TipoElemento.imagen:
      if (e.imagenBase64 == null || e.imagenBase64!.isEmpty) {
        return Container(color: Colors.grey.shade200);
      }
      return Image.memory(
        base64Decode(e.imagenBase64!),
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    case TipoElemento.mapa:
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
              predios: predios,
              baseLayer: e.mapaBaseLayer ?? 'estandar',
              mostrarEtiquetasClave: e.mapaMostrarClaves ?? false,
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
    case TipoElemento.norte:
      return const NorteWidget();
    case TipoElemento.escala:
      return EscalaGraficaWidget(
        metrosPorMm: _metrosPorMmDe(e, hojaElementos, scale),
        anchoDisponibleMm: e.width,
      );
    case TipoElemento.simbologia:
      return SimbologiaWidget(tipo: e.simbologiaTipo ?? TipoSimbologia.estatus);
    case TipoElemento.grafica:
      return GraficaWidget(
        tipo: e.graficaTipo ?? TipoGrafica.kpiPanel,
        predios: predios,
        proyectoItem: proyectoItem,
      );
  }
}

/// Metros reales por milímetro de hoja, derivados del zoom/latitud del
/// mapa asociado a un elemento de escala (`e.escalaMapaId`). Fórmula
/// estándar de Web Mercator para metros por píxel de tile (a
/// `pixelRatio` 1, igual que se captura en `ComposicionExportService`),
/// multiplicada por [scale] (px de render por mm de hoja) para pasar de
/// "metros por píxel" a "metros por milímetro".
double? _metrosPorMmDe(ElementoComposicion e, List<ElementoComposicion> hojaElementos, double scale) {
  final mapaId = e.escalaMapaId;
  if (mapaId == null) return null;
  ElementoComposicion? mapa;
  for (final el in hojaElementos) {
    if (el.id == mapaId && el.tipo == TipoElemento.mapa) {
      mapa = el;
      break;
    }
  }
  if (mapa == null || mapa.mapaLat == null || mapa.mapaZoom == null) return null;
  final metrosPorPixel = 156543.03392 * math.cos(mapa.mapaLat! * math.pi / 180) / math.pow(2, mapa.mapaZoom!);
  return metrosPorPixel * scale;
}

/// Estilo de texto de un elemento [TipoElemento.texto], compartido entre
/// el modo edición (`TextField`) y el modo display (`Text`) de
/// [ElementoBox], y el render estático usado al exportar.
TextStyle textoEstiloDe(ElementoComposicion e) {
  final fontFamily = e.textoFontFamily ?? 'Inter';
  final fontWeight = (e.textoBold ?? false) ? FontWeight.bold : FontWeight.normal;
  final fontStyle = (e.textoItalic ?? false) ? FontStyle.italic : FontStyle.normal;
  final fontSize = e.textoFontSize ?? 16;
  final color = colorFromHex(e.textoColorHex) ?? Colors.black;
  final height = e.textoInterlineado ?? 1.2;
  final letterSpacing = e.textoTracking;
  final decoration = TextDecoration.combine([
    if (e.textoSubrayado ?? false) TextDecoration.underline,
    if (e.textoTachado ?? false) TextDecoration.lineThrough,
  ]);
  // 'Arial' no está en el catálogo de Google Fonts (es una fuente
  // propietaria del sistema, no hosteada por Google) -usar la fuente
  // nativa del navegador/SO en vez de `GoogleFonts.getFont`, que
  // lanzaría una excepción al no encontrarla.
  if (fontFamily == 'Arial') {
    return TextStyle(
      fontFamily: 'Arial',
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }
  return GoogleFonts.getFont(
    fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    decoration: decoration,
  );
}

/// Alineación horizontal (widget) correspondiente a [ElementoComposicion
/// .textoAlineacion].
TextAlign textoAlignDe(ElementoComposicion e) {
  switch (e.textoAlineacion ?? AlineacionTexto.izquierda) {
    case AlineacionTexto.izquierda:
      return TextAlign.left;
    case AlineacionTexto.centro:
      return TextAlign.center;
    case AlineacionTexto.derecha:
      return TextAlign.right;
    case AlineacionTexto.justificado:
      return TextAlign.justify;
  }
}

/// Texto de un elemento [TipoElemento.texto], con "buffer" opcional: un
/// halo/contorno detrás del relleno normal (técnica típica de rotulación
/// cartográfica para mantener legibilidad sobre fondos variables) -se
/// dibuja pintando el mismo texto dos veces: primero con `Paint` en modo
/// `stroke` (el contorno) y encima con el relleno normal.
Widget _buildTexto(ElementoComposicion e) {
  final estilo = textoEstiloDe(e);
  final align = textoAlignDe(e);
  final contenido = e.textoContenido ?? '';
  // `width: double.infinity` fuerza que el texto ocupe todo el ancho
  // disponible del recuadro -si no, `Text` se ajusta a su propio ancho
  // intrínseco y `textAlign` no tendría espacio sobre el cual alinear-.
  if (!(e.textoBufferActivo ?? false)) {
    return SizedBox(
      width: double.infinity,
      child: Text(contenido, style: estilo, textAlign: align),
    );
  }
  final colorBuffer = colorFromHex(e.textoBufferColorHex) ?? Colors.white;
  final anchoBuffer = e.textoBufferAncho ?? 3;
  final estiloTrazo = TextStyle(
    fontFamily: estilo.fontFamily,
    fontFamilyFallback: estilo.fontFamilyFallback,
    fontSize: estilo.fontSize,
    fontWeight: estilo.fontWeight,
    fontStyle: estilo.fontStyle,
    height: estilo.height,
    letterSpacing: estilo.letterSpacing,
    foreground: Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = anchoBuffer
      ..color = colorBuffer,
  );
  return SizedBox(
    width: double.infinity,
    child: Stack(
      children: [
        Text(contenido, style: estiloTrazo, textAlign: align),
        Text(contenido, style: estilo, textAlign: align),
      ],
    ),
  );
}
