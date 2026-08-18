import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/composicion.dart';
import '../models/hoja.dart';

class ComposicionesRepository {
  ComposicionesRepository(this._collection);

  final CollectionReference<Map<String, dynamic>> _collection;

  Future<String> crear({
    required String nombre,
    required String proyecto,
    required String? createdByUid,
    required String? createdByEmail,
  }) async {
    final hoja = Hoja.nueva(nombre: 'Hoja 1');
    final doc = await _collection.add({
      'nombre': nombre,
      'proyecto': proyecto,
      'hojas': [hoja.toMap()],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'created_by_uid': createdByUid,
      'created_by_email': createdByEmail,
    });
    return doc.id;
  }

  Future<void> guardar(Composicion composicion) async {
    await _collection.doc(composicion.id).set({
      'nombre': composicion.nombre,
      'proyecto': composicion.proyecto,
      'hojas': composicion.hojas.map((h) => h.toMap()).toList(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> renombrar(String id, String nombre) async {
    await _collection.doc(id).set({
      'nombre': nombre,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> eliminar(String id) => _collection.doc(id).delete();

  Future<Composicion?> obtener(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Composicion.fromFirestore(doc);
  }
}
