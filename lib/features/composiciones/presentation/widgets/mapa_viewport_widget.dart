import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../mapa/utils/geometry_parsing.dart';
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
/// capturada ahí (ver `VistaMapa`) se vea igual al insertarse aquí -antes
/// siempre salía con mapa estándar y sin etiquetas, sin importar cómo se
/// hubiera capturado la vista-.
class MapaViewportWidget extends StatelessWidget {
  const MapaViewportWidget({
    super.key,
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.predios,
    this.interactivo = false,
    this.onPosicionCambiada,
    this.baseLayer = 'estandar',
    this.mostrarEtiquetasClave = false,
  });

  final double lat;
  final double lng;
  final double zoom;
  final List<Predio> predios;
  final bool interactivo;
  final void Function(double lat, double lng, double zoom)? onPosicionCambiada;
  final String baseLayer;
  final bool mostrarEtiquetasClave;

  /// Mismas URLs que `_tileTemplate` en `mapa_screen.dart`, duplicadas
  /// aquí (no se importa esa pantalla por ser un archivo enorme y
  /// sensible; ver el mismo criterio ya aplicado en
  /// `lib/features/mapa/utils/geometry_parsing.dart`).
  String? _tileTemplate() {
    switch (baseLayer) {
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
    for (final predio in predios) {
      if (predio.geometry == null) continue;
      final rings = extractRingsFromGeometry(predio.geometry);
      if (rings.isEmpty) continue;
      final color = AppColors.rangoEstatusColor(predio.rangoEstatus);
      poligonos.add(Polygon(
        points: rings.first,
        holePointsList: rings.length > 1 ? rings.sublist(1) : const [],
        color: color.withValues(alpha: 0.35),
        borderColor: color,
        borderStrokeWidth: 1.5,
      ));
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
    if (!mostrarEtiquetasClave) return const [];
    final marcadores = <Marker>[];
    for (final predio in predios) {
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
                    Shadow(color: Colors.white, blurRadius: 3, offset: Offset(1, 1)),
                    Shadow(color: Colors.white, blurRadius: 3, offset: Offset(-1, 1)),
                    Shadow(color: Colors.white, blurRadius: 3, offset: Offset(1, -1)),
                    Shadow(color: Colors.white, blurRadius: 3, offset: Offset(-1, -1)),
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

  @override
  Widget build(BuildContext context) {
    final tileTemplate = _tileTemplate();
    final etiquetas = _construirEtiquetasClave();
    return ColoredBox(
      color: baseLayer == 'sinMapa' ? Colors.white : Colors.transparent,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat, lng),
          initialZoom: zoom,
          interactionOptions: InteractionOptions(
            flags: interactivo ? InteractiveFlag.all : InteractiveFlag.none,
          ),
          onPositionChanged: interactivo
              ? (camera, hasGesture) {
                  onPosicionCambiada?.call(camera.center.latitude, camera.center.longitude, camera.zoom);
                }
              : null,
        ),
        children: [
          if (tileTemplate != null)
            TileLayer(
              urlTemplate: tileTemplate,
              userAgentPackageName: 'com.geoportal.predios',
            ),
          PolygonLayer(polygons: _construirPoligonos()),
          if (etiquetas.isNotEmpty) MarkerLayer(markers: etiquetas),
        ],
      ),
    );
  }
}
