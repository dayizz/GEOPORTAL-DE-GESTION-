import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/predio.dart';

final prediosRepositoryProvider = Provider<PrediosRepository>(
  (ref) => PrediosRepository(FirebaseFirestore.instance),
);

/// Resultado de `PrediosRepository.upsertPredioPorClave`: si `fusionado` es
/// true, la fila/feature se combinó (join) con un registro existente en vez
/// de crear uno nuevo.
class UpsertPorClaveResult {
  final Predio predio;
  final bool fusionado;

  const UpsertPorClaveResult({required this.predio, required this.fusionado});
}

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
      'fecha_limite_pago': _timestampToIso(raw['fecha_limite_pago']),
      'poligono_dwg': raw['poligono_dwg']?.toString(),
      'plano_pdf': raw['plano_pdf']?.toString(),
      'bdt': raw['bdt']?.toString(),
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
      'rango_estatus': raw['rango_estatus']?.toString(),
      'rango_estatus_fecha': _timestampToIso(raw['rango_estatus_fecha']),
      'polygon_ref_id': raw['polygon_ref_id']?.toString(),
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

  // Firestore no admite arrays anidados (ej. coordinates de GeoJSON:
  // array de arrays de [lng, lat]); escribir un Map con esa forma directamente
  // hace que el SDK nativo lance una excepción no capturable en Dart y aborte
  // el proceso. Por eso se serializa a String antes de escribir; la lectura
  // (_normalizePredioMap) ya sabe decodificar tanto String como Map.
  void _encodeGeometryForWrite(Map<String, dynamic> payload) {
    final geometry = payload['geometry'];
    if (geometry is Map) {
      payload['geometry'] = jsonEncode(geometry);
    }
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
    _encodeGeometryForWrite(payload);

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
    _encodeGeometryForWrite(payload);

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

  /// Elimina un predio de Gestión sin dejar "huérfanas" a sus afectaciones.
  ///
  /// Si el predio a borrar es el "ancla" de un polígono compartido (otros
  /// registros apuntan a él vía `polygon_ref_id`), se promueve al primero de
  /// esos hermanos como nueva ancla (hereda la `geometry`) y se reapuntan los
  /// demás hermanos hacia él antes de borrar el registro original.
  Future<void> eliminarPredioConReasignacion(String id) async {
    final doc = await _predios.doc(id).get();
    if (!doc.exists) return;

    final dependientes = await _predios.where('polygon_ref_id', isEqualTo: id).get();

    if (dependientes.docs.isNotEmpty) {
      final geometry = doc.data()?['geometry'];
      final nuevaAncla = dependientes.docs.first;
      final resto = dependientes.docs.skip(1);

      final batch = _firestore.batch();
      batch.set(
        nuevaAncla.reference,
        {'geometry': geometry, 'polygon_ref_id': null, 'updated_at': _isoNow()},
        SetOptions(merge: true),
      );
      for (final hermano in resto) {
        batch.set(
          hermano.reference,
          {'polygon_ref_id': nuevaAncla.id, 'updated_at': _isoNow()},
          SetOptions(merge: true),
        );
      }
      batch.delete(_predios.doc(id));
      await batch.commit();
      return;
    }

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
    final payload = <String, dynamic>{
      'geometry': geometry,
      'id_poligono': idPoligono,
      'poligono_insertado': true,
      'updated_at': _isoNow(),
    };
    _encodeGeometryForWrite(payload);

    await _predios.doc(idGestion).set(payload, SetOptions(merge: true));

    final updated = await getPredioById(idGestion);
    if (updated == null) {
      throw Exception('No se pudo vincular el poligono en Firestore');
    }
    return updated;
  }

  /// Vincula un mismo polígono importado a VARIOS registros de Gestión a la
  /// vez (afectaciones repetidas sobre un mismo predio físico): el primer id
  /// de la lista se convierte en el "ancla" (guarda la geometría propia); el
  /// resto solo guarda `polygon_ref_id` apuntando al ancla, para compartir un
  /// único polígono en el mapa sin duplicar la geometría en cada documento.
  Future<void> vincularPoligonoConPredios({
    required String idPoligono,
    required List<String> idsGestion,
    required Map<String, dynamic> geometry,
  }) async {
    if (idsGestion.isEmpty) return;
    final ancla = idsGestion.first;

    final payloadAncla = <String, dynamic>{
      'geometry': geometry,
      'id_poligono': idPoligono,
      'poligono_insertado': true,
      'polygon_ref_id': null,
      'updated_at': _isoNow(),
    };
    _encodeGeometryForWrite(payloadAncla);

    final batch = _firestore.batch();
    batch.set(_predios.doc(ancla), payloadAncla, SetOptions(merge: true));
    for (final id in idsGestion.skip(1)) {
      batch.set(
        _predios.doc(id),
        {'polygon_ref_id': ancla, 'updated_at': _isoNow()},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Todos los documentos que comparten `claveCatastral` (opcionalmente
  /// excluyendo uno), usado para detectar afectaciones repetidas del mismo
  /// predio físico al importar o vincular.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _buscarDocsPorClave(
    String claveCatastral, {
    String? excluirId,
  }) async {
    final clave = claveCatastral.trim();
    if (clave.isEmpty) return const [];
    final query = await _predios.where('clave_catastral', isEqualTo: clave).get();
    return query.docs.where((d) => d.id != excluirId).toList();
  }

  /// Si un predio recién creado (sin geometría propia) tiene hermanos con la
  /// misma clave catastral, busca el polígono que ya comparten (uno con
  /// `geometry` propia, o el ancla que alguno de ellos ya referencia) para
  /// heredar el mismo vínculo y aparecer en el mismo polígono del mapa.
  Future<String?> buscarPoligonoAnclaPorClave(String claveCatastral) async {
    final hermanos = await _buscarDocsPorClave(claveCatastral);
    for (final doc in hermanos) {
      if (doc.data()['geometry'] != null) return doc.id;
    }
    for (final doc in hermanos) {
      final ref = doc.data()['polygon_ref_id']?.toString().trim();
      if (ref != null && ref.isNotEmpty) return ref;
    }
    return null;
  }

  /// Tras crear/actualizar un predio con geometría propia (un "predio
  /// vectorial"), vincula automáticamente cualquier hermano por clave
  /// catastral que aún no tenga polígono propio ni vínculo, para que todas
  /// las afectaciones repetidas compartan un único polígono en el mapa.
  Future<void> autoVincularHermanosPorClave({
    required String claveCatastral,
    required String idAncla,
  }) async {
    final hermanos = await _buscarDocsPorClave(claveCatastral, excluirId: idAncla);
    if (hermanos.isEmpty) return;

    final batch = _firestore.batch();
    var huboActualizacion = false;
    for (final doc in hermanos) {
      final raw = doc.data();
      final tieneGeometriaPropia = raw['geometry'] != null;
      final yaVinculado = (raw['polygon_ref_id']?.toString().trim().isNotEmpty ?? false);
      if (tieneGeometriaPropia || yaVinculado) continue;
      batch.set(
        doc.reference,
        {'polygon_ref_id': idAncla, 'updated_at': _isoNow()},
        SetOptions(merge: true),
      );
      huboActualizacion = true;
    }
    if (huboActualizacion) await batch.commit();
  }

  /// Guarda una fila/feature importado, decidiendo si debe fusionarse con
  /// un registro existente de la misma clave o crear uno nuevo:
  ///
  /// - 0 registros previos con esa clave -> se crea uno nuevo (caso normal).
  /// - Exactamente 1 registro previo, y esta es la PRIMERA vez que el
  ///   archivo que se está importando trae esta clave (`forzarNuevoRegistro
  ///   == false`) -> se FUSIONA con ese registro (join): normalmente es el
  ///   "otro lado" del mismo predio físico (el vectorial -GeoJSON, con
  ///   geometría- y el tabular -XLSX, con propietario/superficie/etc.-
  ///   descrito en dos archivos distintos), heredando datos mutuamente sin
  ///   duplicar el registro en Gestión.
  /// - 2+ registros previos, o el archivo actual ya trajo esta misma clave
  ///   antes (`forzarNuevoRegistro == true`) -> esta fila representa una
  ///   afectación repetida distinta sobre el mismo predio físico (relación
  ///   1:N real: la misma clave aparece más de una vez DENTRO del mismo
  ///   archivo de origen): se crea un registro nuevo vinculado al mismo
  ///   polígono (`polygon_ref_id`), sin duplicar la geometría.
  ///
  /// Importante: la fusión NUNCA compara el contenido de los campos para
  /// decidir -dos archivos que describen el mismo predio (geojson+xlsx)
  /// pueden traer valores ligeramente distintos para el mismo campo sin que
  /// eso signifique una afectación distinta-. La única señal confiable de
  /// "relación 1:N real" es que el propio archivo de origen liste la misma
  /// clave más de una vez; por eso quien llama a este método (los
  /// importadores) es quien indica `forzarNuevoRegistro` cuando detecta esa
  /// repetición dentro del archivo.
  Future<UpsertPorClaveResult> upsertPredioPorClave(
    Map<String, dynamic> payload, {
    bool forzarNuevoRegistro = false,
  }) async {
    final clave = payload['clave_catastral']?.toString().trim() ?? '';
    if (clave.isEmpty) {
      return UpsertPorClaveResult(predio: await createPredio(payload), fusionado: false);
    }

    final hermanos = await _buscarDocsPorClave(clave);

    if (hermanos.length == 1 && !forzarNuevoRegistro) {
      final doc = hermanos.first;
      final update = _mergeParaActualizar(doc.data(), payload);
      update['updated_at'] = _isoNow();
      _encodeGeometryForWrite(update);
      await doc.reference.set(update, SetOptions(merge: true));
      final actualizado = await getPredioById(doc.id);
      return UpsertPorClaveResult(predio: actualizado!, fusionado: true);
    }

    final tieneGeometriaPropia = payload['geometry'] != null;
    if (hermanos.isNotEmpty && !tieneGeometriaPropia) {
      final anclaExistente = await buscarPoligonoAnclaPorClave(clave);
      if (anclaExistente != null) {
        payload['polygon_ref_id'] = anclaExistente;
      }
    }

    final creado = await createPredio(payload);
    if (tieneGeometriaPropia && hermanos.isNotEmpty) {
      await autoVincularHermanosPorClave(claveCatastral: clave, idAncla: creado.id);
    }
    return UpsertPorClaveResult(predio: creado, fusionado: false);
  }

  // Placeholders que el propio importador inyecta cuando un archivo no trae
  // el dato (Firestore exige 'tramo'/'tipo_propiedad' no vacíos en cada
  // documento). Un campo que solo tiene el placeholder -no un valor real
  // capturado por el usuario- se trata como vacío en `_esVacioCampo`.
  static const _placeholdersPorCampo = {
    'tramo': 'S/T',
    'tipo_propiedad': 'PRIVADA',
    'uso_suelo': 'Otro',
  };
  // 'poligono_insertado' esta ligado a si el documento tiene geometry
  // propia; no debe tratarse como "vacío cuando es false" igual que el
  // resto de booleanos, porque un archivo tabular sin geometría podría
  // marcarlo true sin que exista un polígono real.
  static const _booleanRatchetExcluidos = {'poligono_insertado'};

  bool _esVacioCampo(String key, dynamic v) {
    if (v == null) return true;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty || t == _placeholdersPorCampo[key];
    }
    // Los booleanos tipo checklist (identificacion/levantamiento/
    // negociacion/cop) solo avanzan de false->true entre archivos: un
    // 'false' (el default cuando no se detectó el dato) se trata como
    // vacío para que un segundo archivo con el dato real (Si/No) pueda
    // completarlo; un 'true' ya confirmado nunca se pisa.
    if (v is bool && !_booleanRatchetExcluidos.contains(key)) return v == false;
    return false;
  }

  /// Combina un documento existente con una fila/feature entrante: por cada
  /// campo, si el existente ya tiene un valor no vacío se conserva (no se
  /// pisa un dato ya cargado), y si está vacío se toma el del entrante. La
  /// `geometry` es un caso especial: si el existente no tiene geometría
  /// propia y el entrante sí, se adopta (y se limpia `polygon_ref_id`).
  Map<String, dynamic> _mergeParaActualizar(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final update = <String, dynamic>{};
    incoming.forEach((key, value) {
      if (key == 'clave_catastral' || key == 'geometry') return;
      if (_esVacioCampo(key, value)) return;
      if (_esVacioCampo(key, existing[key])) {
        update[key] = value;
      }
    });

    if (existing['geometry'] == null && incoming['geometry'] != null) {
      update['geometry'] = incoming['geometry'];
      update['polygon_ref_id'] = null;
      update['poligono_insertado'] = true;
    }

    return update;
  }
}
