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
        ),
      );
    case TipoElemento.texto:
      return Container(
        color: colorFromHex(e.textoColorFondoHex),
        padding: const EdgeInsets.all(4),
        alignment: Alignment.topLeft,
        child: Text(e.textoContenido ?? '', style: textoEstiloDe(e)),
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
      return MapaViewportWidget(
        lat: e.mapaLat ?? 20.72,
        lng: e.mapaLng ?? -100.35,
        zoom: e.mapaZoom ?? 12,
        predios: predios,
        baseLayer: e.mapaBaseLayer ?? 'estandar',
        mostrarEtiquetasClave: e.mapaMostrarClaves ?? false,
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
  return GoogleFonts.getFont(
    e.textoFontFamily ?? 'Inter',
    fontSize: e.textoFontSize ?? 16,
    fontWeight: (e.textoBold ?? false) ? FontWeight.bold : FontWeight.normal,
    fontStyle: (e.textoItalic ?? false) ? FontStyle.italic : FontStyle.normal,
    color: colorFromHex(e.textoColorHex) ?? Colors.black,
  );
}
