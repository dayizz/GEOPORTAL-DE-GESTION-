import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mapa_provider.dart';

typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

void clearImportedMapState(ProviderReader read) {
  read(importedFeaturesProvider.notifier).state = const [];
  read(pksPointFeaturesProvider.notifier).state = const [];
  read(focusPredioIdProvider.notifier).state = null;
  read(manualVincularPredioIdProvider.notifier).state = null;
}