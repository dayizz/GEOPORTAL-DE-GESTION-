import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

const bool localOnlyAuthMode = false;
const String localAdminEmail = 'admin@sao.mx';
const String localAdminPassword = 'admin123';

/// Mapeo de contraseña a código de proyecto.
const Map<String, String> proyectoPasswords = {
  'TQI123': 'TQI',
  'TSNL123': 'TSNL',
  'TQM123': 'TQM',
  'TAP123': 'TAP',
};

/// Devuelve el código de proyecto si la contraseña corresponde a uno, null si es admin general.
String? extractProyectoFromPassword(String password) {
  return proyectoPasswords[password];
}

/// Proyecto activo para la sesión actual (null = acceso total / admin)
final proyectoActivoProvider = StateProvider<String?>((ref) => null);

final localAuthSessionProvider = StateProvider<bool>((ref) => false);

// Provider del usuario autenticado
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull;
});

// Provider para operaciones de auth
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(FirebaseAuth.instance),
);

class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository(this._auth);

  Future<void> signInWithEmail(String email, String password) async {
    if (localOnlyAuthMode) {
      if (email.trim().toLowerCase() == localAdminEmail &&
          password == localAdminPassword) {
        return;
      }
      throw Exception('Credenciales locales inválidas.');
    }

    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUpWithEmail(String email, String password) async {
    if (localOnlyAuthMode) {
      throw Exception('Registro deshabilitado en modo local.');
    }

    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    if (localOnlyAuthMode) return;
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    if (localOnlyAuthMode) {
      throw Exception('Reset de contrasena no disponible en modo local');
    }
    await _auth.sendPasswordResetEmail(email: email);
  }

  User? get currentUser => _auth.currentUser;
}
