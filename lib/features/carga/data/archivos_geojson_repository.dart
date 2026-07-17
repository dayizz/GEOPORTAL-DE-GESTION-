import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final archivosGeoJsonRepositoryProvider = Provider<ArchivosGeoJsonRepository>(
  (ref) => ArchivosGeoJsonRepository(FirebaseFirestore.instance),
);

class ArchivosGeoJsonRepository {
  ArchivosGeoJsonRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static const _uuid = Uuid();
  static const int _maxStoredFeatures = 10000;
  static const int _maxStoredFeaturesBytes = 5000000;

  CollectionReference<Map<String, dynamic>> get _archivos =>
      _firestore.collection('archivos_geojson');

  String _toIso(dynamic value, {required DateTime fallback}) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed.toIso8601String();
    }
    return fallback.toIso8601String();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase().trim();
      return v == 'true' || v == '1' || v == 'si' || v == 'sí' || v == 'yes';
    }
    return false;
  }

  List<dynamic> _toFeatures(dynamic value) {
    if (value is List) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  List<Map<String, dynamic>> _featuresForStorage(List<Map<String, dynamic>> features) {
    if (features.isEmpty) return const [];

    final kept = <Map<String, dynamic>>[];
    var bytes = 0;

    for (final feature in features) {
      final encoded = jsonEncode(feature);
      final encodedBytes = utf8.encode(encoded).length;
      final exceedsCount = kept.length >= _maxStoredFeatures;
      final exceedsBytes = (bytes + encodedBytes) > _maxStoredFeaturesBytes;
      if (exceedsCount || exceedsBytes) break;

      kept.add(feature);
      bytes += encodedBytes;
    }

    return kept;
  }

  /// Devuelve todos los archivos; el filtrado por perfil (Gestor solo ve
  /// los suyos + los que no tienen dueño registrado) se aplica en la UI,
  /// ya que un archivo sin `created_by_uid` (importado antes de asociar
  /// dueño) no debe quedar invisible/imborrable para nadie.
  Future<List<Map<String, dynamic>>> getArchivos() async {
    final snap = await _archivos.get();

    final normalized = snap.docs.map((doc) {
      final row = Map<String, dynamic>.from(doc.data());
      final now = DateTime.now();
      return <String, dynamic>{
        'id': doc.id,
        'nombre': row['nombre']?.toString() ?? 'archivo',
        'features_count': _toInt(row['features_count']),
        'features': _toFeatures(row['features']),
        'sincronizado': _toBool(row['sincronizado']),
        'encontrados': _toInt(row['encontrados']),
        'creados': _toInt(row['creados']),
        'errores': _toInt(row['errores']),
        'created_by_uid': row['created_by_uid']?.toString(),
        'created_by_email': row['created_by_email']?.toString(),
        'created_at': _toIso(row['created_at'], fallback: now),
        'updated_at': row['updated_at'] == null
            ? null
            : _toIso(row['updated_at'], fallback: now),
      };
    }).toList();

    normalized.sort((a, b) {
      final aDate = DateTime.parse(a['created_at'] as String);
      final bDate = DateTime.parse(b['created_at'] as String);
      return bDate.compareTo(aDate);
    });

    return normalized;
  }

  Future<Map<String, dynamic>> saveArchivo({
    required String nombre,
    required List<Map<String, dynamic>> features,
    int? rowCount,
    bool sincronizado = false,
    int encontrados = 0,
    int creados = 0,
    int errores = 0,
    String? createdByUid,
    String? createdByEmail,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();
    final storedFeatures = _featuresForStorage(features);

    final entry = <String, dynamic>{
      'nombre': nombre,
      'features_count': rowCount ?? features.length,
      'features': storedFeatures,
      'features_stored': storedFeatures.length,
      'features_truncated': storedFeatures.length < features.length,
      'sincronizado': sincronizado,
      'encontrados': encontrados,
      'creados': creados,
      'errores': errores,
      'created_by_uid': createdByUid,
      'created_by_email': createdByEmail,
      'created_at': now,
      'updated_at': now,
    };

    await _archivos.doc(id).set(entry);
    return {'id': id, ...entry};
  }

  Future<void> deleteArchivo(String id) async {
    await _archivos.doc(id).delete();
  }

  /// Borra exactamente los archivos indicados por id (la UI ya resolvió
  /// cuáles son visibles/borrables para el usuario actual).
  Future<void> deleteAll(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.delete(_archivos.doc(id));
    }
    await batch.commit();
  }
}
