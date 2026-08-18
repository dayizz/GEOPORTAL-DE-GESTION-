import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Un PK (placa kilometrica) dentro de un Cadenamiento: identificado por la
/// letra de su Tipo de division (S/T/F) + un numero manual, p.ej. "S1".
class CadenamientoPk {
  final String id;
  final String numeroId;
  final String pkInicio; // texto libre, formato Kilometro+Metros (ej. "12+345")
  final String pkFin;

  const CadenamientoPk({
    required this.id,
    required this.numeroId,
    required this.pkInicio,
    required this.pkFin,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'numero_id': numeroId,
        'pk_inicio': pkInicio,
        'pk_fin': pkFin,
      };

  factory CadenamientoPk.fromMap(Map<String, dynamic> map) => CadenamientoPk(
        id: (map['id'] as String?) ?? const Uuid().v4(),
        numeroId: (map['numero_id'] as String?) ?? '',
        pkInicio: (map['pk_inicio'] as String?) ?? '',
        pkFin: (map['pk_fin'] as String?) ?? '',
      );
}

/// Un bloque de cadenamiento: un Tipo de division con su lista de PK's.
class Cadenamiento {
  final String id;
  final String tipoDivision; // 'Segmento' | 'Tramo' | 'Frente'
  final List<CadenamientoPk> pks;

  const Cadenamiento({
    required this.id,
    required this.tipoDivision,
    required this.pks,
  });

  static const Map<String, String> letras = {
    'Segmento': 'S',
    'Tramo': 'T',
    'Frente': 'F',
  };

  String get letra => letras[tipoDivision] ?? 'T';

  Map<String, dynamic> toMap() => {
        'id': id,
        'tipo_division': tipoDivision,
        'pks': pks.map((p) => p.toMap()).toList(),
      };

  factory Cadenamiento.fromMap(Map<String, dynamic> map) => Cadenamiento(
        id: (map['id'] as String?) ?? const Uuid().v4(),
        tipoDivision: (map['tipo_division'] as String?) ?? 'Tramo',
        pks: (map['pks'] as List<dynamic>? ?? const [])
            .map((e) => CadenamientoPk.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Modelo para proyectos del sistema. Es la única fuente de verdad de qué
/// códigos de proyecto existen en el geoportal (Gestión, Mapa, Reportes,
/// Propietarios, importador, etc. deben leer de aquí, no de listas fijas).
class ProyectoItem {
  final String id;
  final String nombre;
  final String descripcion;
  final bool activo;
  final DateTime createdAt;
  final List<Cadenamiento> cadenamientos;

  const ProyectoItem({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.activo,
    required this.createdAt,
    this.cadenamientos = const [],
  });

  ProyectoItem copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    bool? activo,
    DateTime? createdAt,
    List<Cadenamiento>? cadenamientos,
  }) {
    return ProyectoItem(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      cadenamientos: cadenamientos ?? this.cadenamientos,
    );
  }

  factory ProyectoItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtRaw = data['created_at'];
    final createdAt = createdAtRaw is Timestamp ? createdAtRaw.toDate() : DateTime.now();

    return ProyectoItem(
      id: doc.id,
      nombre: (data['nombre'] as String?) ?? '',
      descripcion: (data['descripcion'] as String?) ?? '',
      activo: (data['activo'] as bool?) ?? true,
      createdAt: createdAt,
      cadenamientos: (data['cadenamientos'] as List<dynamic>? ?? const [])
          .map((e) => Cadenamiento.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'activo': activo,
        'cadenamientos': cadenamientos.map((c) => c.toMap()).toList(),
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': FieldValue.serverTimestamp(),
      };
}
