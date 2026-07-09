import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/mapa/providers/mapa_provider.dart';
import 'package:geoportal_predios/features/mapa/providers/mapa_state_cleanup.dart';

void main() {
  test('clearImportedMapState resets imported map state providers', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(importedFeaturesProvider.notifier).state = [
      {
        'type': 'Feature',
        'properties': {'clave_catastral': 'ABC-1'},
      },
    ];
    container.read(pksPointFeaturesProvider.notifier).state = [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [-100.1, 25.6],
        },
        'properties': {'label': 'PKS-01'},
      },
    ];
    container.read(focusPredioIdProvider.notifier).state = 'predio-1';
    container.read(manualVincularPredioIdProvider.notifier).state = 'predio-2';

    clearImportedMapState(container.read);

    expect(container.read(importedFeaturesProvider), isEmpty);
    expect(container.read(pksPointFeaturesProvider), isEmpty);
    expect(container.read(focusPredioIdProvider), isNull);
    expect(container.read(manualVincularPredioIdProvider), isNull);
  });
}