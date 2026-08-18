import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Parseo de geometría GeoJSON-ish (`Polygon`/`MultiPolygon`) a anillos de
/// `LatLng` para `flutter_map`, con reconocimiento automático de
/// orden lng/lat y un fallback UTM->WGS84 (zonas de México) para
/// geometrías proyectadas en metros en vez de grados.
///
/// Copiado tal cual de la lógica ya probada en
/// `lib/features/mapa/presentation/mapa_screen.dart` (funciones privadas
/// `_extractPolygons`/`_extractRings`/`_ringToLatLng`/etc.) para
/// reutilizarla en el viewport de mapa de "Composiciones" sin tocar la
/// pantalla de Mapa (evita riesgo de regresión en una pantalla grande y
/// ya afinada). Si en el futuro se quiere una única fuente de verdad,
/// `mapa_screen.dart` podría migrar a importar este archivo en vez de su
/// copia interna.
List<List<List<LatLng>>> extractPolygonsFromGeometry(Map<String, dynamic>? geometry) {
  if (geometry == null) return const [];
  final type = geometry['type'] as String?;
  final coords = geometry['coordinates'];
  if (type == null || coords is! List || coords.isEmpty) return const [];
  if (type == 'Polygon') {
    final rings = coords
        .whereType<List>()
        .map(_ringToLatLng)
        .where((ring) => ring.length >= 3)
        .toList();
    return rings.isEmpty ? const [] : [rings];
  }
  if (type == 'MultiPolygon') {
    final polygons = <List<List<LatLng>>>[];
    for (final polygon in coords.whereType<List>()) {
      final rings = polygon
          .whereType<List>()
          .map(_ringToLatLng)
          .where((ring) => ring.length >= 3)
          .toList();
      if (rings.isNotEmpty) polygons.add(rings);
    }
    return polygons;
  }
  return const [];
}

List<List<LatLng>> extractRingsFromGeometry(Map<String, dynamic>? geometry) {
  final polygons = extractPolygonsFromGeometry(geometry);
  return polygons.isEmpty ? const [] : polygons.first;
}

List<LatLng> _ringToLatLng(List<dynamic> ring) {
  try {
    final pairs = <(double, double)>[];
    for (final coord in ring.whereType<List>()) {
      if (coord.length < 2) continue;
      final x = _parseCoord(coord[0]);
      final y = _parseCoord(coord[1]);
      if (x == null || y == null || x.isNaN || y.isNaN) continue;
      pairs.add((x, y));
    }
    if (pairs.isEmpty) return const [];
    // 1) GeoJSON estándar [lng, lat] o invertido [lat, lng]
    final direct = pairs
        .map((p) {
          final x = p.$1;
          final y = p.$2;
          if (_isValidLatLng(lat: y, lng: x)) return LatLng(y, x);
          if (_isValidLatLng(lat: x, lng: y)) return LatLng(x, y);
          return null;
        })
        .whereType<LatLng>()
        .toList();
    if (direct.length >= 3) {
      return direct;
    }
    // 2) Fallback UTM (común en archivos geolocalizados de México)
    final sampleX = pairs.map((p) => p.$1).toList();
    final sampleY = pairs.map((p) => p.$2).toList();
    final utmZone = _detectMexicoUtmZone(sampleX, sampleY);
    if (utmZone == null) {
      return const [];
    }
    final converted = pairs
        .map((p) {
          final ll = _utmToWgs84(p.$1, p.$2, utmZone);
          final lng = ll[0];
          final lat = ll[1];
          if (!_isValidLatLng(lat: lat, lng: lng)) return null;
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();
    return converted;
  } catch (_) {
    return const [];
  }
}

double? _parseCoord(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool _isValidLatLng({required double lat, required double lng}) {
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

int? _detectMexicoUtmZone(List<double> sampleX, List<double> sampleY) {
  if (sampleX.isEmpty || sampleY.isEmpty) return null;
  final x = sampleX.first;
  final y = sampleY.first;
  for (final zone in [14, 15, 13, 16]) {
    final ll = _utmToWgs84(x, y, zone);
    final lng = ll[0];
    final lat = ll[1];
    if (lat >= 13 && lat <= 34 && lng >= -120 && lng <= -84) {
      return zone;
    }
  }
  return null;
}

List<double> _utmToWgs84(double easting, double northing, int zone, {bool isNorth = true}) {
  const a = 6378137.0;
  const f = 1 / 298.257223563;
  const k0 = 0.9996;
  const e0 = 500000.0;
  final e2 = 2 * f - f * f;
  final ePrime2 = e2 / (1 - e2);
  final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
  final x = easting - e0;
  final y = isNorth ? northing : northing - 10000000.0;
  final m = y / k0;
  final mu = m / (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256));
  final phi1 = mu +
      (3 * e1 / 2 - 27 * math.pow(e1, 3) / 32) * math.sin(2 * mu) +
      (21 * e1 * e1 / 16 - 55 * math.pow(e1, 4) / 32) * math.sin(4 * mu) +
      (151 * math.pow(e1, 3) / 96) * math.sin(6 * mu) +
      (1097 * math.pow(e1, 4) / 512) * math.sin(8 * mu);
  final sinPhi1 = math.sin(phi1);
  final cosPhi1 = math.cos(phi1);
  final tanPhi1 = math.tan(phi1);
  final n1 = a / math.sqrt(1 - e2 * sinPhi1 * sinPhi1);
  final t1 = tanPhi1 * tanPhi1;
  final c1 = ePrime2 * cosPhi1 * cosPhi1;
  final r1 = a * (1 - e2) / math.pow(1 - e2 * sinPhi1 * sinPhi1, 1.5);
  final d = x / (n1 * k0);
  final lat = phi1 -
      (n1 * tanPhi1 / r1) *
          (d * d / 2 -
              (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * ePrime2) * math.pow(d, 4) / 24 +
              (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * ePrime2 - 3 * c1 * c1) * math.pow(d, 6) / 720);
  final lambda0 = ((zone - 1) * 6 - 180 + 3) * math.pi / 180;
  final lng = lambda0 +
      (d -
              (1 + 2 * t1 + c1) * math.pow(d, 3) / 6 +
              (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * ePrime2 + 24 * t1 * t1) * math.pow(d, 5) / 120) /
          cosPhi1;
  return [lng * 180 / math.pi, lat * 180 / math.pi];
}
