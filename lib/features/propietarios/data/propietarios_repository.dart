import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/import_normalization.dart' as norm;
import '../../predios/models/propietario.dart';

final propietariosRepositoryProvider = Provider<PropietariosRepository>(
  (ref) => PropietariosRepository(FirebaseFirestore.instance),
);

class PropietariosRepository {
  PropietariosRepository(this._firestore);

  final FirebaseFirestore _firestore;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _propietarios =>
      _firestore.collection('propietarios');

  String _isoNow() => DateTime.now().toIso8601String();

  String _toIso(dynamic value, {required DateTime fallback}) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed.toIso8601String();
    }
    return fallback.toIso8601String();
  }

  Map<String, dynamic> _normalizePropietarioMap(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final raw = Map<String, dynamic>.from(doc.data() ?? const {});
    final now = DateTime.now();
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
      'created_at': _toIso(raw['created_at'], fallback: now),
      'updated_at': raw['updated_at'] == null
          ? null
          : _toIso(raw['updated_at'], fallback: now),
    };
  }

  Future<List<Propietario>> getPropietarios({
    String? busqueda,
    String? tipoPersona,
    int limit = 100,
  }) async {
    final snap = await _propietarios.get();

    var propietarios = snap.docs
        .map((doc) => Propietario.fromMap(_normalizePropietarioMap(doc)))
        .toList();

    if (busqueda != null && busqueda.trim().isNotEmpty) {
      final q = busqueda.trim().toLowerCase();
      propietarios = propietarios.where((p) {
        return p.nombre.toLowerCase().contains(q) ||
            p.apellidos.toLowerCase().contains(q) ||
            (p.rfc?.toLowerCase().contains(q) ?? false) ||
            (p.curp?.toLowerCase().contains(q) ?? false) ||
            (p.razonSocial?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (tipoPersona != null && tipoPersona.isNotEmpty) {
      propietarios = propietarios.where((p) => p.tipoPersona == tipoPersona).toList();
    }

    propietarios.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    if (propietarios.length > limit) {
      return propietarios.sublist(0, limit);
    }
    return propietarios;
  }

  Future<Propietario?> getPropietarioById(String id) async {
    final doc = await _propietarios.doc(id).get();
    if (!doc.exists) return null;
    return Propietario.fromMap(_normalizePropietarioMap(doc));
  }

  Future<Propietario> createPropietario(Map<String, dynamic> data) async {
    final id = (data['id']?.toString().trim().isNotEmpty ?? false)
        ? data['id'].toString().trim()
        : _uuid.v4();

    final payload = <String, dynamic>{
      ...data,
      'created_at': data['created_at']?.toString() ?? _isoNow(),
      'updated_at': _isoNow(),
    }..remove('id');

    await _propietarios.doc(id).set(payload, SetOptions(merge: true));
    final created = await getPropietarioById(id);
    if (created == null) {
      throw Exception('No se pudo crear el propietario en Firestore');
    }
    return created;
  }

  Future<Propietario> findOrCreateByNombreCompleto(String nombreCompleto) async {
    return findOrCreateFromData({'nombre_completo': nombreCompleto});
  }

  Future<Propietario> findOrCreateFromData(Map<String, dynamic> data) async {
    String nombre;
    String apellidos;

    // Capitalización + sin acentos, para que "José"/"Jose"/"JOSE" y
    // "María Pérez"/"MARIA PEREZ" terminen siendo el mismo propietario en
    // vez de crear duplicados por cómo venía escrito en el archivo origen.
    if (data['nombre'] != null && data['nombre'].toString().isNotEmpty) {
      nombre = norm.normalizeTitleCase(data['nombre'].toString()) ?? '';
      apellidos = norm.normalizeTitleCase(data['apellidos']?.toString()) ?? '';
    } else {
      final full = norm.normalizeTitleCase((data['nombre_completo'] ?? '').toString()) ?? '';
      if (full.isEmpty) throw ArgumentError('Se requiere nombre del propietario');
      final parts = full.split(' ');
      nombre = parts.first;
      apellidos = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    final all = await getPropietarios(limit: 5000);
    final rfc = norm.normalizeCode(data['rfc']?.toString());

    Propietario? existing;
    if (rfc != null && rfc.isNotEmpty) {
      for (final item in all) {
        if ((item.rfc ?? '').trim().toUpperCase() == rfc.toUpperCase()) {
          existing = item;
          break;
        }
      }
    }

    existing ??= all.where((item) {
      return item.nombre.trim().toUpperCase() == nombre.toUpperCase() &&
          item.apellidos.trim().toUpperCase() == apellidos.toUpperCase();
    }).firstOrNull;

    final curp = norm.normalizeCode(data['curp']?.toString());
    final telefono = data['telefono']?.toString().trim();
    final correo = data['correo']?.toString().trim().toLowerCase();

    if (existing != null) {
      final updates = <String, dynamic>{};
      if (rfc != null && rfc.isNotEmpty && (existing.rfc == null || existing.rfc!.isEmpty)) {
        updates['rfc'] = rfc;
      }
      if (curp != null && curp.isNotEmpty && (existing.curp == null || existing.curp!.isEmpty)) {
        updates['curp'] = curp;
      }
      if (telefono != null && telefono.isNotEmpty && (existing.telefono == null || existing.telefono!.isEmpty)) {
        updates['telefono'] = telefono;
      }
      if (correo != null && correo.isNotEmpty && (existing.correo == null || existing.correo!.isEmpty)) {
        updates['correo'] = correo;
      }

      if (updates.isNotEmpty) {
        await updatePropietario(existing.id, updates);
        final updated = await getPropietarioById(existing.id);
        if (updated != null) return updated;
      }

      return existing;
    }

    final razonSocial = norm.normalizeTitleCase(data['razon_social']?.toString());
    final nombreCompleto = '$nombre $apellidos'.trim().toUpperCase();
    final tipoPersona = data['tipo_persona']?.toString() ??
        ((razonSocial != null && razonSocial.isNotEmpty) ||
                nombreCompleto.contains('S.A.') ||
                nombreCompleto.contains('S.DE R.L.') ||
                nombreCompleto.contains('SAPI') ||
                nombreCompleto.contains('SAS')
            ? 'moral'
            : 'fisica');

    final insertData = <String, dynamic>{
      'nombre': nombre,
      'apellidos': apellidos,
      'tipo_persona': tipoPersona,
      if (razonSocial != null && razonSocial.isNotEmpty) 'razon_social': razonSocial,
      if (rfc != null && rfc.isNotEmpty) 'rfc': rfc,
      if (curp != null && curp.isNotEmpty) 'curp': curp,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      if (correo != null && correo.isNotEmpty) 'correo': correo,
    };

    return createPropietario(insertData);
  }

  Future<Propietario> updatePropietario(String id, Map<String, dynamic> data) async {
    final payload = <String, dynamic>{
      ...data,
      'updated_at': _isoNow(),
    }..remove('id');

    await _propietarios.doc(id).set(payload, SetOptions(merge: true));
    final updated = await getPropietarioById(id);
    if (updated == null) {
      throw Exception('No se pudo actualizar el propietario en Firestore');
    }
    return updated;
  }

  Future<void> deletePropietario(String id) async {
    await _propietarios.doc(id).delete();
  }
}
