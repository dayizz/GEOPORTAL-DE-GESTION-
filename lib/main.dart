import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // En web Firestore no guarda caché por defecto: cada inicio de sesión
  // descargaba de nuevo todos los predios y sus polígonos. Con IndexedDB
  // el mapa pinta primero lo guardado y después solo baja los cambios.
  // `synchronizeTabs` permite tener varias pestañas abiertas a la vez. Se
  // borra al cerrar sesión (ver `closeSessionAndClearState`).
  if (kIsWeb) {
    try {
      await FirebaseFirestore.instance
          .enablePersistence(const PersistenceSettings(synchronizeTabs: true));
    } catch (e) {
      // Navegador sin IndexedDB (p. ej. modo privado): sigue sin caché.
      debugPrint('Firestore sin caché persistente: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: GeoportalApp(),
    ),
  );
}
