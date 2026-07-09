import 'dart:convert';

import 'geojson_mapper.dart';

Set<String> extractClavesFromFeatures(List<Map<String, dynamic>> features) {
  final claves = <String>{};
  for (final feature in features) {
    final rawProps = feature['properties'];
    if (rawProps is! Map) continue;
    final props = Map<String, dynamic>.from(rawProps);
    final clave = _extractNormalizedClave(props);
    if (clave != null && clave.isNotEmpty) {
      claves.add(clave);
    }
  }
  return claves;
}

String? _extractNormalizedClave(Map<String, dynamic> props) {
  final normalized = GeoJsonMapper.normalizeProperties(props);
  final canonicalClave =
      normalized['clave_catastral']?.toString().trim().toUpperCase();
  if (canonicalClave != null && canonicalClave.isNotEmpty) {
    return canonicalClave;
  }

  for (final entry in props.entries) {
    final normalizedKey = entry.key
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalizedKey == 'clavecatastral' || normalizedKey == 'idcatastral') {
      final value = entry.value?.toString().trim().toUpperCase();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
  }

  return null;
}

bool shouldClearImportedMapAfterFileDeletion({
  required List<Map<String, dynamic>> currentImported,
  required List<Map<String, dynamic>> fileFeatures,
}) {
  return identical(currentImported, fileFeatures) ||
      (currentImported.isNotEmpty &&
          fileFeatures.isNotEmpty &&
          currentImported.length == fileFeatures.length &&
          jsonEncode(currentImported.first) == jsonEncode(fileFeatures.first));
}