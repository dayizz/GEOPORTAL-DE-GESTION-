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

  /// Crea una copia de la composición [id] con todas sus hojas y
  /// elementos, llamada "Copia de (nombre original)". Copia el documento
  /// tal cual está guardado (no lo que muestra la lista) y el usuario que
  /// duplica queda como creador. Devuelve el id de la copia.
  Future<String?> duplicar(
    String id, {
    required String? createdByUid,
    required String? createdByEmail,
  }) async {
    final original = await _collection.doc(id).get();
    final data = original.data();
    if (data == null) return null;
    final nombre = (data['nombre'] as String?)?.trim();
    var copia = 'Copia de ${nombre == null || nombre.isEmpty ? 'Sin nombre' : nombre}';
    // Las reglas de Firestore limitan el nombre a 120 caracteres.
    if (copia.length > 120) copia = copia.substring(0, 120).trimRight();
    final doc = await _collection.add({
      ...data,
      'nombre': copia,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'created_by_uid': createdByUid,
      'created_by_email': createdByEmail,
    });
    return doc.id;
  }

  Future<Composicion?> obtener(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Composicion.fromFirestore(doc);
  }
}
