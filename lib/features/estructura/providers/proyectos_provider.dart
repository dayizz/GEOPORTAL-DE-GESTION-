import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/proyecto_item.dart';

final proyectosCollectionProvider =
    Provider<CollectionReference<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('proyectos');
});

/// Stream de proyectos (y su cadenamiento) persistidos en Firestore. Fuente
/// única de verdad: alta/baja de un proyecto en Estructura debe reflejarse
/// aquí y, por lo tanto, en cualquier pantalla que consuma este provider.
final proyectosProvider = StreamProvider<List<ProyectoItem>>((ref) {
  final collection = ref.watch(proyectosCollectionProvider);
  return collection
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map(ProyectoItem.fromFirestore).toList(growable: false));
});

/// Códigos de proyecto vigentes (nombre de cada [ProyectoItem], en
/// mayúsculas), derivados en vivo de Firestore. Se incluyen tanto activos
/// como inactivos: un proyecto inactivo puede seguir teniendo predios ya
/// registrados que deben permanecer filtrables/visibles.
///
/// Úsese en vez de listas fijas como `['TQI', 'TSNL', 'TAP', 'TMQ']` en
/// cualquier pantalla o servicio que necesite saber qué proyectos existen.
final proyectosCodigosProvider = Provider<List<String>>((ref) {
  final proyectos = ref.watch(proyectosProvider).valueOrNull ?? const [];
  return proyectos
      .map((p) => p.nombre.trim().toUpperCase())
      .where((codigo) => codigo.isNotEmpty)
      .toList(growable: false);
});
