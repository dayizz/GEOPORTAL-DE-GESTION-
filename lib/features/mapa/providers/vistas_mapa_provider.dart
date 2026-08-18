import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/vistas_mapa_repository.dart';
import '../models/vista_mapa.dart';

final vistasMapaCollectionProvider = Provider<CollectionReference<Map<String, dynamic>>>(
  (ref) => FirebaseFirestore.instance.collection('vistas_mapa'),
);

final vistasMapaRepositoryProvider = Provider<VistasMapaRepository>(
  (ref) => VistasMapaRepository(ref.watch(vistasMapaCollectionProvider)),
);

/// Stream de todas las vistas de mapa guardadas (de todos los proyectos);
/// las pantallas filtran por proyecto, igual que `composicionesProvider`.
final vistasMapaProvider = StreamProvider<List<VistaMapa>>((ref) {
  final collection = ref.watch(vistasMapaCollectionProvider);
  return collection.snapshots().map(
        (snapshot) => snapshot.docs.map(VistaMapa.fromFirestore).toList(growable: false),
      );
});
