import 'package:cloud_firestore/cloud_firestore.dart';
import 'hoja.dart';

/// Una composición: un conjunto de [Hoja] guardado en Firestore
/// (colección `composiciones`), asociado a un proyecto.
class Composicion {
  final String id;
  final String nombre;
  final String proyecto;
  final List<Hoja> hojas;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdByUid;
  final String? createdByEmail;

  const Composicion({
    required this.id,
    required this.nombre,
    required this.proyecto,
    required this.hojas,
    required this.createdAt,
    this.updatedAt,
    this.createdByUid,
    this.createdByEmail,
  });

  Composicion copyWith({
    String? nombre,
    List<Hoja>? hojas,
  }) {
    return Composicion(
      id: id,
      nombre: nombre ?? this.nombre,
      proyecto: proyecto,
      hojas: hojas ?? this.hojas,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdByUid: createdByUid,
      createdByEmail: createdByEmail,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'proyecto': proyecto,
        'hojas': hojas.map((h) => h.toMap()).toList(),
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': FieldValue.serverTimestamp(),
        'created_by_uid': createdByUid,
        'created_by_email': createdByEmail,
      };

  factory Composicion.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtRaw = data['created_at'];
    final updatedAtRaw = data['updated_at'];
    return Composicion(
      id: doc.id,
      nombre: (data['nombre'] as String?) ?? 'Sin nombre',
      proyecto: (data['proyecto'] as String?) ?? '',
      hojas: (data['hojas'] as List<dynamic>? ?? const [])
          .map((h) => Hoja.fromMap(Map<String, dynamic>.from(h as Map)))
          .toList(),
      createdAt: createdAtRaw is Timestamp ? createdAtRaw.toDate() : DateTime.now(),
      updatedAt: updatedAtRaw is Timestamp ? updatedAtRaw.toDate() : null,
      createdByUid: data['created_by_uid'] as String?,
      createdByEmail: data['created_by_email'] as String?,
    );
  }
}
