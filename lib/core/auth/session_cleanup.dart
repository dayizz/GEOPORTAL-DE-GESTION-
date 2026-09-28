import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/mapa/providers/mapa_provider.dart';
import '../../features/mapa/providers/mapa_state_cleanup.dart';

const sessionLastActivityKey = 'geoportal_last_activity_ms';

/// Cierra la sesión remota y limpia el estado local asociado al usuario.
Future<void> closeSessionAndClearState(WidgetRef ref) async {
  try {
    await ref.read(authRepositoryProvider).signOut();
  } catch (_) {
    // La limpieza local debe continuar aunque el proveedor remoto falle.
  }

  ref.read(localAuthSessionProvider.notifier).state = false;
  ref.read(proyectoActivoProvider.notifier).state = null;
  clearImportedMapState(ref.read);
  ref.read(gestionProyectoProvider.notifier).state = null;
  ref.read(importacionAsyncProvider.notifier).reset();

  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(sessionLastActivityKey);
  } catch (_) {
    // La expiración y el cierre de sesión no dependen del almacenamiento.
  }
}
