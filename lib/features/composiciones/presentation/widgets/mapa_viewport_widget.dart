import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../mapa/utils/geometry_parsing.dart';
import '../../../mapa/utils/pks_label.dart';
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
    this.rotacion = 0,
    this.opacidadMapa = 1,
    this.opacidadPredios = 0.35,
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

  /// Rotación (grados) del contenido del mapa en sí -no de la ventana que
  /// lo contiene, ver `rotacion` en `ElementoComposicion`-.
  final double rotacion;

  /// Opacidad (0-1) de la capa de mosaico del mapa base.
  final double opacidadMapa;

  /// Opacidad (0-1) del relleno/trazo de los polígonos de predios.
  final double opacidadPredios;

  @override
  State<MapaViewportWidget> createState() => _MapaViewportWidgetState();
}

class _MapaViewportWidgetState extends State<MapaViewportWidget> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant MapaViewportWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  List<Polygon> _construirPoligonos() {
    final poligonos = <Polygon>[];
    for (final predio in widget.predios) {
      if (predio.geometry == null) continue;
      final rings = extractRingsFromGeometry(predio.geometry);
      if (rings.isEmpty) continue;
      final color = AppColors.rangoEstatusColor(predio.rangoEstatus);
      poligonos.add(
        Polygon(
          points: rings.first,
          holePointsList: rings.length > 1 ? rings.sublist(1) : const [],
          color: color.withValues(alpha: widget.opacidadPredios),
          borderColor: color.withValues(alpha: widget.opacidadPredios),
          borderStrokeWidth: 1.5,
        ),
      );
    }
    return poligonos;
  }

  List<Polygon> _construirPoligonosImportados() {
    final poligonos = <Polygon>[];
    for (final feature in widget.importedFeatures) {
      final geometry = feature['geometry'];
      if (geometry is! Map) continue;
      final polygons = extractPolygonsFromGeometry(
        Map<String, dynamic>.from(geometry),
      );
      for (final rings in polygons) {
        if (rings.isEmpty || rings.first.isEmpty) continue;
        poligonos.add(
          Polygon(
            points: rings.first,
            holePointsList: rings.length > 1 ? rings.sublist(1) : const [],
            color: AppColors.primary.withValues(alpha: 0.28),
            borderColor: AppColors.primary,
            borderStrokeWidth: 1.8,
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

  List<Marker> _construirEtiquetasClave() {
    if (!widget.mostrarEtiquetasClave) return const [];
    final marcadores = <Marker>[];
    for (final predio in widget.predios) {
      final clave = predio.claveCatastral.trim();
      if (clave.isEmpty || predio.geometry == null) continue;
      final rings = extractRingsFromGeometry(predio.geometry);
      if (rings.isEmpty) continue;
      final centro = _centroide(rings.first);
      if (centro == null) continue;
      marcadores.add(
        Marker(
          point: centro,
          width: 160,
          height: 20,
          child: IgnorePointer(
            child: Center(
              child: Text(
                clave,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  shadows: [
                    Shadow(
                      color: Colors.white,
                      blurRadius: 3,
                      offset: Offset(1, 1),
                    ),
                    Shadow(
                      color: Colors.white,
                      blurRadius: 3,
                      offset: Offset(-1, 1),
                    ),
                    Shadow(
                      color: Colors.white,
                      blurRadius: 3,
                      offset: Offset(1, -1),
                    ),
                    Shadow(
                      color: Colors.white,
                      blurRadius: 3,
                      offset: Offset(-1, -1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
      final geometry = feature['geometry'];
      if (geometry is! Map) continue;
      final puntos = extractPointsFromGeometry(
        Map<String, dynamic>.from(geometry),
      );
      if (puntos.isEmpty) continue;
      final label = _extractPksLabel(feature);
      if (label.isEmpty) continue;
      for (final punto in puntos) {
        marcadores.add(
          Marker(
            point: punto,
            width: 160,
            height: 20,
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    shadows: [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 3,
                        offset: Offset(1, 1),
                      ),
                      Shadow(
                        color: Colors.white,
                        blurRadius: 3,
                        offset: Offset(-1, 1),
                      ),
                      Shadow(
                        color: Colors.white,
                        blurRadius: 3,
                        offset: Offset(1, -1),
                      ),
                      Shadow(
                        color: Colors.white,
                        blurRadius: 3,
                        offset: Offset(-1, -1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return marcadores;
  }

  @override
  Widget build(BuildContext context) {
    final tileTemplate = _tileTemplate();
    final etiquetas = _construirEtiquetasClave();
    final etiquetasPks = _construirEtiquetasPks();
    return ColoredBox(
      color: widget.baseLayer == 'sinMapa' ? Colors.white : Colors.transparent,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(widget.lat, widget.lng),
          initialZoom: widget.zoom,
          initialRotation: widget.rotacion,
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
            polygons: [
              ..._construirPoligonos(),
              ..._construirPoligonosImportados(),
            ],
          ),
          if (etiquetas.isNotEmpty) MarkerLayer(markers: etiquetas),
          if (etiquetasPks.isNotEmpty) MarkerLayer(markers: etiquetasPks),
        ],
      ),
    );
  }
}
