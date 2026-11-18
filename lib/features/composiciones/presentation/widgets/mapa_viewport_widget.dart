import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/elemento_composicion.dart';
import '../../utils/color_hex.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../mapa/utils/geometry_parsing.dart';
import '../../../mapa/utils/pks_label.dart';
import '../../../mapa/utils/trazo_metadata.dart';
import '../../../predios/models/predio.dart';

/// Viewport de mapa de solo datos (sin Riverpod): recibe la lista de
/// [predios] ya resuelta por quien lo instancia (la pantalla del editor,
/// o el servicio de exportación) en vez de leerla con `ref.watch`
/// internamente. Esto es necesario porque `ScreenshotController
/// .captureFromWidget` (usado para exportar) construye un árbol de
/// widgets desconectado del árbol principal de la app -no hereda el
/// `ProviderScope`-, así que un `ConsumerWidget` fallaría ahí.
///
/// Cuando [interactivo] es `false` (elemento no seleccionado para editar,
/// o exportación) el mapa se muestra fijo, sin gestos propios, para que
/// el arrastre/selección del elemento en el lienzo funcione con
/// normalidad. Cuando es `true` (el usuario entró en modo edición de
/// mapa con doble click) el mapa se vuelve navegable y reporta la nueva
/// posición/zoom vía [onPosicionCambiada].
///
/// [baseLayer] y [mostrarEtiquetasClave] replican el tipo de mapa base
/// ('estandar'/'satelital'/'satelitalSinEtiquetas'/'sinMapa', ver
/// `MapaBaseLayer` en `mapa_provider.dart`) y el toggle de etiquetas de
/// clave catastral de la pantalla Mapa, para que una "vista de mapa"
/// configurada en el elemento se vea igual al renderizarse aquí.
/// siempre salía con mapa estándar y sin etiquetas, sin importar cómo se
/// hubiera capturado la vista-.
///
/// Es `StatefulWidget` (con [MapController] propio) en vez de
/// `StatelessWidget` porque `MapOptions.initialCenter/initialZoom
/// /initialRotation` de flutter_map solo siembran la cámara la PRIMERA
/// vez que se crea -cambios posteriores a esos parámetros en rebuilds no
/// mueven una cámara ya inicializada-. [didUpdateWidget] detecta cambios
/// externos (p.ej. desde el panel de propiedades: escala/zoom/rotación)
/// y los aplica explícitamente vía el controller.
class MapaViewportWidget extends StatefulWidget {
  const MapaViewportWidget({
    super.key,
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.predios,
    this.importedFeatures = const [],
    this.pksFeatures = const [],
    this.interactivo = false,
    this.onPosicionCambiada,
    this.baseLayer = 'estandar',
    this.mostrarEtiquetasClave = false,
    this.mostrarPks = false,
    this.estiloClave = const EstiloEtiquetaMapa(),
    this.estiloPks = const EstiloEtiquetaMapa(),
    this.rotacion = 0,
    this.opacidadMapa = 1,
    this.opacidadPredios = 0.35,
    this.prediosOcultos = const {},
    this.trazosOcultos = const {},
  });

  final double lat;
  final double lng;
  final double zoom;
  final List<Predio> predios;
  final List<Map<String, dynamic>> importedFeatures;

  /// Features GeoJSON de puntos PKS importados en la sesión (ver
  /// `pksPointFeaturesProvider`), igual que [importedFeatures] pero para
  /// esa capa -no se persiste con el elemento, solo su etiqueta [mostrarPks].
  final List<Map<String, dynamic>> pksFeatures;
  final bool interactivo;
  final void Function(double lat, double lng, double zoom)? onPosicionCambiada;
  final String baseLayer;
  final bool mostrarEtiquetasClave;

  /// Si se dibujan las etiquetas de texto de [pksFeatures].
  final bool mostrarPks;
  final EstiloEtiquetaMapa estiloClave;
  final EstiloEtiquetaMapa estiloPks;

  /// Rotación (grados) del contenido del mapa en sí -no de la ventana que
  /// lo contiene, ver `rotacion` en `ElementoComposicion`-.
  final double rotacion;

  /// Opacidad (0-1) de la capa de mosaico del mapa base.
  final double opacidadMapa;

  /// Opacidad (0-1) del relleno/trazo de los polígonos de predios.
  final double opacidadPredios;

  /// "Datos filtrados": categorías de predios (`categoriasPrediosMapa`) y
  /// tipos de línea del trazo (`tiposLinea`) que no se dibujan.
  final Set<String> prediosOcultos;
  final Set<String> trazosOcultos;

  @override
  State<MapaViewportWidget> createState() => _MapaViewportWidgetState();
}

class _MapaViewportWidgetState extends State<MapaViewportWidget> {
  final MapController _mapController = MapController();
  List<Polygon>? _poligonos;
  List<Polyline>? _lineasTrazo;
  List<Predio>? _prediosVisiblesCache;
  List<Marker>? _etiquetasClave;
  List<Marker>? _etiquetasPks;
  Color? _colorImportados;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }


  @override
  void didUpdateWidget(covariant MapaViewportWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cambioPredios = !listEquals(widget.predios, oldWidget.predios) ||
        !setEquals(widget.prediosOcultos, oldWidget.prediosOcultos);
    if (cambioPredios) _prediosVisiblesCache = null;
    final cambioTrazo = !listEquals(widget.importedFeatures, oldWidget.importedFeatures) ||
        !setEquals(widget.trazosOcultos, oldWidget.trazosOcultos);
    if (cambioPredios || cambioTrazo ||
        widget.opacidadPredios != oldWidget.opacidadPredios) {
      _poligonos = null;
    }
    if (cambioTrazo) _lineasTrazo = null;
    if (widget.estiloClave != oldWidget.estiloClave || cambioPredios || widget.mostrarEtiquetasClave != oldWidget.mostrarEtiquetasClave) {
      _etiquetasClave = null;
    }
    if (widget.estiloPks != oldWidget.estiloPks || !listEquals(widget.pksFeatures, oldWidget.pksFeatures) || widget.mostrarPks != oldWidget.mostrarPks) {
      _etiquetasPks = null;
    }

    if (widget.lat != oldWidget.lat ||
        widget.lng != oldWidget.lng ||
        widget.zoom != oldWidget.zoom) {
      _mapController.move(LatLng(widget.lat, widget.lng), widget.zoom);
    }
    if (widget.rotacion != oldWidget.rotacion) {
      _mapController.rotate(widget.rotacion);
    }
  }

  /// Mismas URLs que `_tileTemplate` en `mapa_screen.dart`, duplicadas
  /// aquí (no se importa esa pantalla por ser un archivo enorme y
  /// sensible; ver el mismo criterio ya aplicado en
  /// `lib/features/mapa/utils/geometry_parsing.dart`).
  String? _tileTemplate() {
    switch (widget.baseLayer) {
      case 'satelital':
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case 'satelitalSinEtiquetas':
        return 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}';
      case 'sinMapa':
        return null;
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  /// Categoría del filtro: "En investigación" (sin tipo de
  /// infraestructura), "Liberados" o "No liberados".
  static String _categoriaPredio(Predio p) {
    if (p.rangoEstatus == 'Investigación') return categoriaPrediosInvestigacion;
    return Predio.estatusSimplificado(p.rangoEstatus) == 'Liberado'
        ? categoriaPrediosLiberados
        : categoriaPrediosNoLiberados;
  }

  List<Predio> get _prediosVisibles => _prediosVisiblesCache ??=
      widget.prediosOcultos.isEmpty
          ? widget.predios
          : widget.predios
              .where((p) => !widget.prediosOcultos.contains(_categoriaPredio(p)))
              .toList(growable: false);

  static Map<String, dynamic>? _geometria(dynamic geometry) {
    if (geometry is String) {
      try {
        geometry = jsonDecode(geometry);
      } catch (_) {
        return null;
      }
    }
    return geometry is Map ? Map<String, dynamic>.from(geometry) : null;
  }

  /// Si [feature] se dibuja: los trazos se filtran por tipo de línea; el
  /// resto de features importados siempre se dibuja.
  bool _featureVisible(Map<String, dynamic> feature) =>
      !esFeatureTrazo(feature) || !widget.trazosOcultos.contains(tipoLineaTrazo(feature));

  /// Líneas del trazo (envolventes `LineString`), con el color de su tipo
  /// de línea, igual que en la vista Mapa.
  List<Polyline> _construirLineasTrazo() {
    final lineas = <Polyline>[];
    for (final feature in widget.importedFeatures) {
      if (!_featureVisible(feature)) continue;
      final color = esFeatureTrazo(feature)
          ? colorTipoLinea(tipoLineaTrazo(feature))
          : AppColors.primary;
      for (final puntos in extractLinesFromGeometry(_geometria(feature['geometry']))) {
        lineas.add(Polyline(
          points: puntos,
          color: color,
          strokeWidth: 3,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ));
      }
    }
    return lineas;
  }

  List<Polygon> _construirPoligonos() {
    final poligonos = <Polygon>[];
    for (final predio in _prediosVisibles) {
      if (predio.geometry == null) continue;
      final rings = extractRingsFromGeometry(predio.geometry);
      if (rings.isEmpty) continue;
      final color = AppColors.rangoEstatusColor(predio.rangoEstatus);
      poligonos.add(
        Polygon(
          points: rings.first,
          holePointsList: rings.length > 1 ? rings.sublist(1) : const [],
          color: color.withValues(alpha: widget.opacidadPredios),
          borderColor: AppColors.rangoEstatusBorderColor(predio.rangoEstatus)
              .withValues(alpha: widget.opacidadPredios),
          borderStrokeWidth: 1.5,
        ),
      );
    }
    return poligonos;
  }

  List<Polygon> _construirPoligonosImportados() {
    final poligonos = <Polygon>[];
    for (final feature in widget.importedFeatures) {
      if (!_featureVisible(feature)) continue;
      final polygons = extractPolygonsFromGeometry(_geometria(feature['geometry']));
      final esTrazo = esFeatureTrazo(feature);
      final color = esTrazo ? colorTipoLinea(tipoLineaTrazo(feature)) : AppColors.primary;
      for (final rings in polygons) {
        if (rings.isEmpty || rings.first.isEmpty) continue;
        poligonos.add(
          Polygon(
            points: rings.first,
            holePointsList: rings.length > 1 ? rings.sublist(1) : const [],
            color: color.withValues(alpha: esTrazo ? 0.18 : 0.28),
            borderColor: color,
            borderStrokeWidth: esTrazo ? 2.5 : 1.8,
          ),
        );
      }
    }
    return poligonos;
  }

  LatLng? _centroide(List<LatLng> ring) {
    if (ring.isEmpty) return null;
    var sumLat = 0.0;
    var sumLng = 0.0;
    for (final punto in ring) {
      sumLat += punto.latitude;
      sumLng += punto.longitude;
    }
    return LatLng(sumLat / ring.length, sumLng / ring.length);
  }

  Marker _etiqueta(LatLng punto, String texto, EstiloEtiquetaMapa estilo,
      {Alignment alignment = Alignment.center}) {
    final base = TextStyle(fontSize: estilo.tamano, fontWeight: FontWeight.w700);
    final fuente = GoogleFonts.asMap().containsKey(estilo.fuente)
        ? GoogleFonts.getFont(estilo.fuente, textStyle: base)
        : base.copyWith(fontFamily: estilo.fuente);
    final medida = TextPainter(
      text: TextSpan(text: texto, style: fuente),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final buffer = estilo.bufferActivo ? estilo.bufferGrosor : 0.0;
    final w = medida.width + buffer * 2 + 4;
    final h = medida.height + buffer * 2 + 4;
    medida.dispose();
    // El marcador debe contener la caja rotada para que no se recorte.
    final rad = estilo.rotacion * math.pi / 180;
    final cos = math.cos(rad).abs(), sin = math.sin(rad).abs();
    final ancho = w * cos + h * sin;
    final alto = w * sin + h * cos;
    return Marker(
      point: punto, width: ancho, height: alto, alignment: alignment,
      child: IgnorePointer(
        // El texto se acomoda sin límite antes de rotarlo: sin el
        // `OverflowBox` heredaba la caja rotada del marcador (a 90° es
        // angosta) y se cortaba; tampoco se corta si la fuente termina de
        // cargar y queda más ancha que la medida.
        child: OverflowBox(
            minWidth: 0, minHeight: 0,
            maxWidth: double.infinity, maxHeight: double.infinity,
            child: Transform.rotate(angle: rad,
            child: Stack(alignment: Alignment.center, children: [
          if (buffer > 0)
            Text(texto, maxLines: 1, style: fuente.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeJoin = StrokeJoin.round
                ..strokeWidth = buffer * 2
                ..color = colorFromHex(estilo.bufferColorHex) ?? Colors.white,
            )),
          Text(texto, maxLines: 1, style: fuente.copyWith(
            color: colorFromHex(estilo.colorHex) ?? Colors.black,
          )),
        ]))),
      ),
    );
  }

  List<Marker> _construirEtiquetasClave() {
    if (!widget.mostrarEtiquetasClave) return const [];
    final marcadores = <Marker>[];
    for (final predio in _prediosVisibles) {
      final clave = predio.claveCatastral.trim();
      if (clave.isEmpty || predio.geometry == null) continue;
      final rings = extractRingsFromGeometry(predio.geometry);
      if (rings.isEmpty) continue;
      final centro = _centroide(rings.first);
      if (centro == null) continue;
      marcadores.add(
        _etiqueta(centro, clave, widget.estiloClave),
      );
    }
    return marcadores;
  }

  /// Etiqueta de texto de un feature PKS: intenta varias propiedades
  /// candidatas (misma lista que `_extractPksPointLabel` en
  /// `mapa_screen.dart`, copiada aquí por el mismo criterio del resto de
  /// este archivo).
  String _extractPksLabel(Map<String, dynamic> feature) {
    final rawProps = feature['properties'];
    if (rawProps is! Map) return '';
    final props = Map<String, dynamic>.from(rawProps);
    return extractPksLabel(props) ?? '';
  }

  List<Marker> _construirEtiquetasPks() {
    if (!widget.mostrarPks) return const [];
    final marcadores = <Marker>[];
    for (final feature in widget.pksFeatures) {
      // La geometría puede venir como mapa o como texto JSON (igual que
      // `_geometryAsMap` en `mapa_screen.dart`).
      var geometry = feature['geometry'];
      if (geometry is String) {
        try {
          geometry = jsonDecode(geometry);
        } catch (_) {
          continue;
        }
      }
      if (geometry is! Map) continue;
      final puntos = extractPointsFromGeometry(
        Map<String, dynamic>.from(geometry),
      );
      if (puntos.isEmpty) continue;
      final label = _extractPksLabel(feature);
      if (label.isEmpty) continue;
      for (final punto in puntos) {
        marcadores.add(
          _etiqueta(punto, label, widget.estiloPks, alignment: Alignment.topCenter),
        );
      }
    }
    return marcadores;
  }

  @override
  Widget build(BuildContext context) {
    final tileTemplate = _tileTemplate();
    if (_colorImportados != AppColors.primary) {
      _colorImportados = AppColors.primary;
      _poligonos = null;
    }
    final poligonos = _poligonos ??= [..._construirPoligonos(), ..._construirPoligonosImportados()];
    final lineasTrazo = _lineasTrazo ??= _construirLineasTrazo();
    final etiquetas = _etiquetasClave ??= _construirEtiquetasClave();
    final etiquetasPks = _etiquetasPks ??= _construirEtiquetasPks();
    // Sin fondo propio: con 'sinMapa' solo se ven los polígonos sobre la
    // hoja (FlutterMap pinta gris por defecto bajo los tiles).
    return RepaintBoundary(child: ColoredBox(
      color: Colors.transparent,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(widget.lat, widget.lng),
          initialZoom: widget.zoom,
          initialRotation: widget.rotacion,
          backgroundColor: Colors.transparent,
          // Sin gesto de rotación: la rotación del contenido del mapa se
          // controla únicamente desde el panel de propiedades (ver
          // `rotacion` arriba), para no chocar con la posición/zoom que sí
          // se ajustan arrastrando el mapa en modo edición.
          interactionOptions: InteractionOptions(
            flags: widget.interactivo
                ? (InteractiveFlag.all & ~InteractiveFlag.rotate)
                : InteractiveFlag.none,
          ),
          onPositionChanged: widget.interactivo
              ? (camera, hasGesture) {
                  widget.onPosicionCambiada?.call(
                    camera.center.latitude,
                    camera.center.longitude,
                    camera.zoom,
                  );
                }
              : null,
        ),
        children: [
          if (tileTemplate != null)
            Opacity(
              opacity: widget.opacidadMapa,
              child: TileLayer(
                urlTemplate: tileTemplate,
                userAgentPackageName: 'com.geoportal.predios',
              ),
            ),
          PolygonLayer(
            polygons: poligonos,
          ),
          if (lineasTrazo.isNotEmpty) PolylineLayer(polylines: lineasTrazo),
          if (etiquetas.isNotEmpty) MarkerLayer(markers: etiquetas),
          if (etiquetasPks.isNotEmpty) MarkerLayer(markers: etiquetasPks),
        ],
      ),
    ));
  }
}
