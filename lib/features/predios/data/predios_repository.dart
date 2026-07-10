import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/predio.dart';

final prediosRepositoryProvider = Provider<PrediosRepository>(
  (ref) => PrediosRepository(FirebaseFirestore.instance),
);

class PrediosRepository {
  PrediosRepository(this._firestore);

  final FirebaseFirestore _firestore;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _predios =>
      _firestore.collection('predios');
  CollectionReference<Map<String, dynamic>> get _propietarios =>
      _firestore.collection('propietarios');

  String _isoNow() => DateTime.now().toIso8601String();

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '').trim());
    return null;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'si' || v == 'sí' || v == 'yes';
    }
    return false;
  }

  String? _timestampToIso(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  Map<String, dynamic> _normalizePropietarioMap(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final raw = Map<String, dynamic>.from(doc.data() ?? const {});
    return {
      'id': doc.id,
      'nombre': raw['nombre']?.toString() ?? '',
      'apellidos': raw['apellidos']?.toString() ?? '',
      'tipo_persona': raw['tipo_persona']?.toString() ?? 'fisica',
      'razon_social': raw['razon_social']?.toString(),
      'curp': raw['curp']?.toString(),
      'rfc': raw['rfc']?.toString(),
      'telefono': raw['telefono']?.toString(),
      'correo': raw['correo']?.toString(),
      'created_at': _timestampToIso(raw['created_at']) ?? _isoNow(),
      'updated_at': _timestampToIso(raw['updated_at']),
    };
  }

  Map<String, dynamic> _normalizePredioMap(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    Map<String, dynamic>? propietario,
  }) {
    final raw = Map<String, dynamic>.from(doc.data() ?? const {});
    final geometryRaw = raw['geometry'];

    Map<String, dynamic>? geometry;
    if (geometryRaw is Map) {
      geometry = Map<String, dynamic>.from(geometryRaw);
    } else if (geometryRaw is String && geometryRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(geometryRaw);
        if (decoded is Map) geometry = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    final map = <String, dynamic>{
      'id': doc.id,
      'clave_catastral': raw['clave_catastral']?.toString().trim() ??
          raw['id_sedatu']?.toString().trim() ??
          '',
      'propietario_nombre': raw['propietario_nombre']?.toString(),
      'tramo': raw['tramo']?.toString() ?? '',
      'tipo_propiedad': raw['tipo_propiedad']?.toString() ?? 'PRIVADA',
      'estructura': raw['estructura']?.toString(),
      'ejido': raw['ejido']?.toString(),
      'estado': raw['estado']?.toString(),
      'municipio': raw['municipio']?.toString(),
      'km_inicio': _toDouble(raw['km_inicio']),
      'km_fin': _toDouble(raw['km_fin']),
      'km_lineales': _toDouble(raw['km_lineales']),
      'km_efectivos': _toDouble(raw['km_efectivos']),
      'superficie': _toDouble(raw['superficie']),
      'cop': _toBool(raw['cop']),
      'cop_firmado': raw['cop_firmado']?.toString(),
      'pdf_url': raw['pdf_url']?.toString(),
      'cop_fecha': _timestampToIso(raw['cop_fecha']),
      'poligono_dwg': raw['poligono_dwg']?.toString(),
      'oficio': raw['oficio']?.toString(),
      'proyecto': raw['proyecto']?.toString(),
      'poligono_insertado': _toBool(raw['poligono_insertado']),
      'identificacion': _toBool(raw['identificacion']),
      'levantamiento': _toBool(raw['levantamiento']),
      'negociacion': _toBool(raw['negociacion']),
      'situacion_social': raw['situacion_social']?.toString(),
      'tipo_liberacion': raw['tipo_liberacion']?.toString(),
      'latitud': _toDouble(raw['latitud']),
      'longitud': _toDouble(raw['longitud']),
      'geometry': geometry,
      'propietario_id': raw['propietario_id']?.toString(),
      'created_at': _timestampToIso(raw['created_at']) ?? _isoNow(),
      'updated_at': _timestampToIso(raw['updated_at']),
    };

    if (propietario != null) {
      map['propietarios'] = propietario;
    }
    return map;
  }

  Future<List<Predio>> getPredios({
    String? busqueda,
    String? usoSuelo,
    String? zona,
    String? propietarioId,
    String? proyecto,
    List<String>? proyectosPermitidos,
    int limit = 10000,
    int offset = 0,
  }) async {
    final allowedProjects = (proyectosPermitidos ?? const <String>[])
        .map((p) => p.trim().toUpperCase())
        .where((p) => p.isNotEmpty)
        .toSet();

    if (proyectosPermitidos != null && allowedProjects.isEmpty) {
      return const [];
    }

    final proyectoFiltro = proyecto?.trim().toUpperCase();

    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = const [];

    if (proyectoFiltro != null && proyectoFiltro.isNotEmpty) {
      if (proyectosPermitidos != null && !allowedProjects.contains(proyectoFiltro)) {
        return const [];
      }
      final snap = await _predios.where('proyecto', isEqualTo: proyectoFiltro).get();
      docs = snap.docs;
    } else if (allowedProjects.isNotEmpty) {
      final futures = allowedProjects
          .map((p) => _predios.where('proyecto', isEqualTo: p).get())
          .toList(growable: false);
      final snapshots = await Future.wait(futures);
      final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          merged[doc.id] = doc;
        }
      }
      docs = merged.values.toList(growable: false);
    } else {
      final snap = await _predios.get();
      docs = snap.docs;
    }

    final propIds = <String>{};
    for (final doc in docs) {
      final raw = doc.data();
      final id = raw['propietario_id']?.toString();
      if (id != null && id.isNotEmpty) propIds.add(id);
    }

    final propietariosById = <String, Map<String, dynamic>>{};
    if (propIds.isNotEmpty) {
      final futures = propIds.map((id) => _propietarios.doc(id).get()).toList();
      final propDocs = await Future.wait(futures);
      for (final doc in propDocs) {
        if (doc.exists) propietariosById[doc.id] = _normalizePropietarioMap(doc);
      }
    }

    var predios = docs.map((doc) {
      final propId = doc.data()['propietario_id']?.toString();
      final propietario = propId != null ? propietariosById[propId] : null;
      return Predio.fromMap(_normalizePredioMap(doc, propietario: propietario));
    }).toList();

    if (busqueda != null && busqueda.trim().isNotEmpty) {
      final q = busqueda.trim().toLowerCase();
      predios = predios.where((p) {
        return p.claveCatastral.toLowerCase().contains(q) ||
            p.direccion.toLowerCase().contains(q) ||
            (p.propietarioNombre ?? '').toLowerCase().contains(q);
      }).toList();
    }

    if (usoSuelo != null && usoSuelo.isNotEmpty) {
      predios = predios.where((p) => p.usoSuelo == usoSuelo).toList();
    }

    if (zona != null && zona.isNotEmpty) {
      predios = predios.where((p) => p.zona == zona).toList();
    }

    if (propietarioId != null && propietarioId.isNotEmpty) {
      predios = predios.where((p) => p.propietarioId == propietarioId).toList();
    }

    predios.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (offset > 0 && offset < predios.length) {
      predios = predios.sublist(offset);
    } else if (offset >= predios.length) {
      return const [];
    }

    if (predios.length > limit) return predios.sublist(0, limit);
    return predios;
  }

  Future<Predio?> getPredioById(String id) async {
    final doc = await _predios.doc(id).get();
    if (!doc.exists) return null;

    final propId = doc.data()?['propietario_id']?.toString();
    Map<String, dynamic>? propietario;
    if (propId != null && propId.isNotEmpty) {
      final propDoc = await _propietarios.doc(propId).get();
      if (propDoc.exists) propietario = _normalizePropietarioMap(propDoc);
    }

    return Predio.fromMap(_normalizePredioMap(doc, propietario: propietario));
  }

  Future<Map<String, dynamic>?> buscarPorClaveCatastral(String clave) async {
    final query = await _predios
        .where('clave_catastral', isEqualTo: clave.trim())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final propId = doc.data()['propietario_id']?.toString();
    Map<String, dynamic>? propietario;
    if (propId != null && propId.isNotEmpty) {
      final propDoc = await _propietarios.doc(propId).get();
      if (propDoc.exists) propietario = _normalizePropietarioMap(propDoc);
    }

    return _normalizePredioMap(doc, propietario: propietario);
  }

  Future<Predio> createPredio(Map<String, dynamic> data) async {
    final id = (data['id']?.toString().trim().isNotEmpty ?? false)
        ? data['id'].toString().trim()
        : _uuid.v4();

    final payload = <String, dynamic>{
      ...data,
      'created_at': data['created_at']?.toString() ?? _isoNow(),
      'updated_at': _isoNow(),
    }..remove('id');

    await _predios.doc(id).set(payload, SetOptions(merge: true));
    final created = await getPredioById(id);
    if (created == null) {
      throw Exception('No se pudo crear el predio en Firestore');
    }
    return created;
  }

  Future<Predio> updatePredio(String id, Map<String, dynamic> data) async {
    final payload = <String, dynamic>{
      ...data,
      'updated_at': _isoNow(),
    }..remove('id');

    await _predios.doc(id).set(payload, SetOptions(merge: true));
    final updated = await getPredioById(id);
    if (updated == null) {
      throw Exception('No se pudo actualizar el predio en Firestore');
    }
    return updated;
  }

  Future<void> deletePredio(String id) async {
    await _predios.doc(id).delete();
  }

  Future<List<Predio>> getPrediosConGeometria() async {
    final all = await getPredios(limit: 100000);
    return all.where((p) => p.geometry != null).toList();
  }

  Future<Map<String, dynamic>> getEstadisticas() async {
    final predios = await getPredios(limit: 100000);
    final conteoUso = <String, int>{};
    var superficieTotal = 0.0;

    for (final p in predios) {
      conteoUso[p.usoSuelo] = (conteoUso[p.usoSuelo] ?? 0) + 1;
      superficieTotal += p.superficie ?? 0;
    }

    return {
      'total': predios.length,
      'por_uso_suelo': conteoUso,
      'superficie_total': superficieTotal,
    };
  }

  Future<Predio> vincularPoligonoConPredio({
    required String idPoligono,
    required String idGestion,
    required Map<String, dynamic> geometry,
  }) async {
    await _predios.doc(idGestion).set(
      {
        'geometry': geometry,
        'id_poligono': idPoligono,
        'poligono_insertado': true,
        'updated_at': _isoNow(),
      },
      SetOptions(merge: true),
    );

    final updated = await getPredioById(idGestion);
    if (updated == null) {
      throw Exception('No se pudo vincular el poligono en Firestore');
    }
    return updated;
  }
}
