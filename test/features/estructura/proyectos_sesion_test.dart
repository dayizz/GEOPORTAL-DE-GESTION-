import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/auth/providers/auth_provider.dart';
import 'package:geoportal_predios/features/estructura/providers/proyectos_provider.dart';

class Usuario extends Fake implements User {
  Usuario(this.uid);
  @override
  final String uid;
}

class Coleccion extends Fake implements CollectionReference<Map<String, dynamic>> {
  int consultas = 0;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    consultas++;
    return Stream.value(Resultado());
  }
}

class Resultado extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
}

void main() {
  test('espera la sesión y vuelve a consultar al cambiar de usuario', () async {
    final sesion = StreamController<User?>();
    final coleccion = Coleccion();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => sesion.stream),
      proyectosCollectionProvider.overrideWithValue(coleccion),
    ]);
    addTearDown(() async {
      container.dispose();
      await sesion.close();
    });
    container.listen(proyectosProvider, (_, __) {});
    sesion.add(null);
    await container.pump();
    expect(coleccion.consultas, 0);
    sesion.add(Usuario('a'));
    await container.pump();
    await container.read(proyectosProvider.future);
    expect(coleccion.consultas, 1);
    sesion.add(Usuario('b'));
    await container.pump();
    await container.read(proyectosProvider.future);
    expect(coleccion.consultas, 2);
    sesion.add(null);
    await container.pump();
    expect(await container.read(proyectosProvider.future), isEmpty);
    expect(coleccion.consultas, 2);
  });
}
