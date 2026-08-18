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

/// Números de feature (1-based, para mostrarle al usuario) que NO tienen
/// ninguna clave catastral resoluble -ni por el campo canónico ni por
/// ningún alias conocido (folio, id_sedatu, cvegeo, id, fid, etc., ver
/// `GeoJsonMapper.normalizeProperties`)-. Se usa para bloquear la
/// importación ANTES de escribir nada: antes, un feature sin clave se
/// sustituía por un identificador inventado (`IMP-<timestamp>`) que
/// parecía una clave real pero era un registro fantasma -ver
/// `SincronizacionService._processFeature`-.
List<int> featuresIndicesSinClave(List<Map<String, dynamic>> features) {
  final indices = <int>[];
  for (var i = 0; i < features.length; i++) {
    final rawProps = features[i]['properties'];
    final props = rawProps is Map ? Map<String, dynamic>.from(rawProps) : <String, dynamic>{};
    final clave = _extractNormalizedClave(props);
    if (clave == null || clave.isEmpty) indices.add(i + 1);
  }
  return indices;
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