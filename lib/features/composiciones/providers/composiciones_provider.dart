import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/composiciones_repository.dart';
import '../models/composicion.dart';

final composicionesCollectionProvider = Provider<CollectionReference<Map<String, dynamic>>>(
  (ref) => FirebaseFirestore.instance.collection('composiciones'),
);

final composicionesRepositoryProvider = Provider<ComposicionesRepository>(
  (ref) => ComposicionesRepository(ref.watch(composicionesCollectionProvider)),
);

/// Stream de todas las composiciones (de todos los proyectos); las
/// pantallas filtran por proyecto activo, igual que `BalanceScreen` hace
/// con `prediosMapaProvider`.
final composicionesProvider = StreamProvider<List<Composicion>>((ref) {
  final collection = ref.watch(composicionesCollectionProvider);
  return collection.snapshots().map(
        (snapshot) => snapshot.docs.map(Composicion.fromFirestore).toList(growable: false),
      );
});
