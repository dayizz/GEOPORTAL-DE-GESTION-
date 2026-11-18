import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../utils/recargar_pagina.dart';
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

  // Borra la caché de Firestore del navegador para que los datos no se
  // queden en el equipo tras cerrar sesión. `clearPersistence` exige
  // detener la instancia, así que la página se recarga para iniciarla de
  // nuevo (el usuario ya va de salida, al inicio de sesión).
  if (kIsWeb) {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.terminate();
      await firestore.clearPersistence();
    } catch (_) {
      // Otra pestaña abierta mantiene la caché; se limpiará al cerrar sesión ahí.
    }
    recargarPagina();
  }
}
