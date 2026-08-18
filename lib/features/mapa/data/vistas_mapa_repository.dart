import 'package:cloud_firestore/cloud_firestore.dart';

class VistasMapaRepository {
  VistasMapaRepository(this._collection);

  final CollectionReference<Map<String, dynamic>> _collection;

  Future<String> crear({
    required String nombre,
    required String proyecto,
    required double lat,
    required double lng,
    required double zoom,
    required String baseLayer,
    required bool mostrarEtiquetasClave,
    required String? createdByUid,
    required String? createdByEmail,
  }) async {
    final doc = await _collection.add({
      'nombre': nombre,
      'proyecto': proyecto,
      'lat': lat,
      'lng': lng,
      'zoom': zoom,
      'base_layer': baseLayer,
      'mostrar_etiquetas_clave': mostrarEtiquetasClave,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'created_by_uid': createdByUid,
      'created_by_email': createdByEmail,
    });
    return doc.id;
  }

  Future<void> actualizar({
    required String id,
    required String nombre,
    required String proyecto,
    required double lat,
    required double lng,
    required double zoom,
    required String baseLayer,
    required bool mostrarEtiquetasClave,
  }) async {
    await _collection.doc(id).set({
      'nombre': nombre,
      'proyecto': proyecto,
      'lat': lat,
      'lng': lng,
      'zoom': zoom,
      'base_layer': baseLayer,
      'mostrar_etiquetas_clave': mostrarEtiquetasClave,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> eliminar(String id) => _collection.doc(id).delete();
}
