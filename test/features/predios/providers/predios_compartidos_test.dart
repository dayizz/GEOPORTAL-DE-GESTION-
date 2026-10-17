import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/auth/providers/auth_provider.dart';
import 'package:geoportal_predios/features/estructura/providers/proyectos_provider.dart';
import 'package:geoportal_predios/features/predios/data/predios_repository.dart';
import 'package:geoportal_predios/features/predios/models/predio.dart';
import 'package:geoportal_predios/features/predios/providers/predios_provider.dart';
import 'package:geoportal_predios/features/predios/providers/local_predios_provider.dart';

class UsuarioPrueba implements User {
  @override
  String get uid => 'usuario-prueba';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RepositorioPrueba implements PrediosRepository {
  final cambios = StreamController<List<Predio>>.broadcast();
  int suscripciones = 0;
  final permisos = <List<String>?>[];
  @override
  Stream<List<Predio>> watchPredios({
    String? proyecto,
    List<String>? proyectosPermitidos,
  }) {
    suscripciones++;
    permisos.add(proyectosPermitidos);
    return cambios.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Predio predio(String id, {String proyecto = 'TSNL', double km = 1}) => Predio(
  id: id,
  claveCatastral: id,
  tramo: 'S1',
  tipoPropiedad: 'PRIVADA',
  estructura: 'DDV Troncal',
  proyecto: proyecto,
  kmInicio: km,
  createdAt: DateTime(2026),
);

void main() {
  late RepositorioPrueba repo;
  late ProviderContainer container;
  setUp(() {
    repo = RepositorioPrueba();
    container = ProviderContainer(
      overrides: [
        prediosRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith((ref) => Stream.value(UsuarioPrueba())),
        canAccessAllProjectsProvider.overrideWithValue(true),
        currentUserAssignedProjectsProvider.overrideWithValue(const []),
        proyectosProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    container.listen(prediosListProvider, (_, __) {});
    container.listen(prediosMapaProvider, (_, __) {});
  });
  tearDown(() async {
    container.dispose();
    await repo.cambios.close();
  });
  test(
    'Gestión y Mapa comparten una sola suscripción y reciben una edición',
    () async {
      await container.pump();
      repo.cambios.add([predio('a')]);
      expect(
        (await container.read(prediosListProvider.future)).single.kmInicio,
        1,
      );
      expect(
        (await container.read(prediosMapaProvider.future)).single.kmInicio,
        1,
      );
      expect(repo.suscripciones, 1);
      repo.cambios.add([predio('a', km: 20)]);
      await container.pump();
      expect(
        (await container.read(prediosListProvider.future)).single.kmInicio,
        20,
      );
      expect(
        (await container.read(prediosMapaProvider.future)).single.kmInicio,
        20,
      );
      expect(repo.suscripciones, 1);
    },
  );
  test(
    'filtrar, actualizar locales o refrescar vistas no repite consultas',
    () async {
      await container.pump();
      repo.cambios.add([predio('a'), predio('b')]);
      await container.read(prediosMapaProvider.future);
      container.read(prediosFiltrosProvider.notifier).state =
          const PrediosFiltros(busqueda: 'a');
      expect((await container.read(prediosListProvider.future)).length, 1);
      container.read(localPrediosProvider.notifier).upsertMany([
        predio('local-c'),
      ]);
      await container.pump();
      expect((await container.read(prediosMapaProvider.future)).length, 3);
      container.invalidate(prediosMapaProvider);
      expect((await container.read(prediosMapaProvider.future)).length, 3);
      expect(repo.suscripciones, 1);
    },
  );
  test(
    'cambiar permisos reemplaza la suscripción y descarta registros no autorizados',
    () async {
      await container.pump();
      repo.cambios.add([predio('a'), predio('b', proyecto: 'TQI')]);
      await container.read(prediosMapaProvider.future);
      container.updateOverrides([
        prediosRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith((ref) => Stream.value(UsuarioPrueba())),
        canAccessAllProjectsProvider.overrideWithValue(false),
        currentUserAssignedProjectsProvider.overrideWithValue(const ['TSNL']),
        proyectosProvider.overrideWith((ref) => Stream.value(const [])),
      ]);
      await container.pump();
      repo.cambios.add([predio('a'), predio('b', proyecto: 'TQI')]);
      await container.pump();
      expect(
        (await container.read(prediosMapaProvider.future)).map((p) => p.id),
        ['a'],
      );
      expect(repo.permisos.last, ['TSNL']);
    },
  );
  test('reintentar reconecta la fuente después de un error de red', () async {
    await container.pump();
    repo.cambios.addError(StateError('sin conexión'));
    await container.pump();
    expect(container.read(prediosRemotosProvider).hasError, isTrue);
    container.invalidate(prediosRemotosProvider);
    await container.pump();
    repo.cambios.add([predio('a')]);
    expect((await container.read(prediosMapaProvider.future)).single.id, 'a');
    expect(repo.suscripciones, 2);
  });

  test('una edición conserva la identidad de los demás registros', () async {
    await container.pump();
    final b = predio('b').copyWith(tramo: '19');
    repo.cambios.add([predio('a'), b]);
    final antes = (await container.read(prediosMapaProvider.future)).last;
    repo.cambios.add([predio('a', km: 9), b]);
    await container.pump();
    final despues = (await container.read(prediosMapaProvider.future)).last;
    expect(identical(antes, despues), isTrue);
    expect(despues.tramo, 'S19');
  });

}
