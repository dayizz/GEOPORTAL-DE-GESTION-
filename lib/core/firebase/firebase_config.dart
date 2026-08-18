import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  FirebaseConfig._();

  static const String apiKey =
      String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
  static const String appId =
      String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
  static const String messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
  static const String projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static const String authDomain =
      String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
  static const String storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
  static const String measurementId =
      String.fromEnvironment('FIREBASE_MEASUREMENT_ID', defaultValue: '');

  // La app real se inicializa en main.dart con
  // `DefaultFirebaseOptions.currentPlatform` (generado por flutterfire-cli),
  // no con estos --dart-define (que nunca se definen en el build real y
  // por eso este check siempre daba falso en producción, aunque Firebase
  // sí estuviera correctamente inicializado). Se verifica el estado real.
  static bool get isConfigured => Firebase.apps.isNotEmpty;

  static FirebaseOptions get options {
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }
}
