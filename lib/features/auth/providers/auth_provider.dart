import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

const bool localOnlyAuthMode = bool.fromEnvironment(
  'LOCAL_ONLY_AUTH_MODE',
  defaultValue: false,
);
const String localAdminEmail = String.fromEnvironment(
  'LOCAL_ADMIN_EMAIL',
  defaultValue: '',
);
const String localAdminPassword = String.fromEnvironment(
  'LOCAL_ADMIN_PASSWORD',
  defaultValue: '',
);
const String _adminApproverEmailsRaw = String.fromEnvironment(
  'ADMIN_APPROVER_EMAILS',
  defaultValue: '',
);
const String _adminApproverUidsRaw = String.fromEnvironment(
  'ADMIN_APPROVER_UIDS',
  defaultValue: 'cZg4LhniabSxLQuosExJrFOJQWw2',
);

const String perfilAdministrador = 'Administrador';
const String perfilGestorProyecto = 'Gestor de proyecto';
const String perfilOperativoAuxiliar = 'Operativo auxiliar';

Set<String> _parseEmails(String raw) => raw
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .where((item) => item.isNotEmpty)
    .toSet();

Set<String> get adminApproverEmails => _parseEmails(_adminApproverEmailsRaw);
Set<String> get adminApproverUids => _parseEmails(_adminApproverUidsRaw);

bool get hasLocalAdminCredentials =>
    localAdminEmail.trim().isNotEmpty && localAdminPassword.isNotEmpty;

bool isAdminApproverEmail(String? email) {
  if (email == null) return false;
  return adminApproverEmails.contains(email.trim().toLowerCase());
}

bool isAdminApproverUser(User? user) {
  if (user == null) return false;
  final email = user.email?.trim().toLowerCase();
  final uid = user.uid.trim().toLowerCase();
  return (email != null && adminApproverEmails.contains(email)) ||
      adminApproverUids.contains(uid);
}

String normalizePerfil(String? raw) {
  final value = (raw ?? '').trim();
  if (value == perfilAdministrador) return perfilAdministrador;
  if (value == perfilGestorProyecto) return perfilGestorProyecto;
  return perfilOperativoAuxiliar;
}

bool isPerfilAdministrador(String? perfil) =>
    normalizePerfil(perfil) == perfilAdministrador;

bool isPerfilGestor(String? perfil) =>
    normalizePerfil(perfil) == perfilGestorProyecto;

bool canViewEstructura(String? perfil) =>
    isPerfilAdministrador(perfil) || isPerfilGestor(perfil);

bool canManageOperationalData(String? perfil) =>
    isPerfilAdministrador(perfil) || isPerfilGestor(perfil);

bool canAccessCarga(String? perfil) => canManageOperationalData(perfil);

bool canAccessProyectosCatalogo(String? perfil) => canManageOperationalData(perfil);

bool canAccessRouteByPerfil(String route, String? perfil) {
  if (route == '/estructura' || route.startsWith('/estructura/')) {
    return canViewEstructura(perfil);
  }

  if (route == '/carga' || route.startsWith('/carga/')) {
    return canAccessCarga(perfil);
  }

  if (route == '/proyectos' || route.startsWith('/proyectos/')) {
    return canAccessProyectosCatalogo(perfil);
  }

  if (route.endsWith('/nuevo') || route.endsWith('/editar')) {
    return canManageOperationalData(perfil);
  }

  return true;
}

final currentUserAssignedProjectsProvider = Provider<List<String>>((ref) {
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  final raw = profile?['proyectos'];
  if (raw is! List) return const <String>[];

  return raw
      .whereType<String>()
      .map((p) => p.trim().toUpperCase())
      .where((p) => p.isNotEmpty)
      .toSet()
      .toList(growable: false);
});

final canAccessAllProjectsProvider = Provider<bool>((ref) {
  final isAdmin = ref.watch(currentUserIsAdminProvider).valueOrNull == true;
  if (isAdmin) {
    return true;
  }

  final perfil = ref.watch(currentUserPerfilProvider);
  return isPerfilAdministrador(perfil);
});

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

final currentUserProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || localOnlyAuthMode) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('usuarios_sistema')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data());
});

final currentUserIsAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return false;
  }

  if (isAdminApproverUser(user)) {
    return true;
  }

  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  if (normalizePerfil(profile?['perfil'] as String?) == perfilAdministrador) {
    return true;
  }

  final token = await user.getIdTokenResult(true);
  final claims = token.claims ?? const <String, dynamic>{};
  return claims['admin'] == true;
});

final currentUserPerfilProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (isAdminApproverUser(user)) {
    return perfilAdministrador;
  }

  final isAdmin = ref.watch(currentUserIsAdminProvider).valueOrNull == true;
  if (isAdmin) {
    return perfilAdministrador;
  }

  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  return normalizePerfil(profile?['perfil'] as String?);
});

/// Garantiza que el usuario autenticado tenga perfil en Firestore.
final ensureCurrentUserProfileProvider = FutureProvider<void>((ref) async {
  if (localOnlyAuthMode) return;
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  await ref.read(authRepositoryProvider).ensureUserProfileExists(user);
});

// Provider para operaciones de auth
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(FirebaseAuth.instance),
);

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthRepository(this._auth);

  CollectionReference<Map<String, dynamic>> get _approvalCodes =>
      _firestore.collection('user_approval_codes');

  CollectionReference<Map<String, dynamic>> get _usuariosSistema =>
      _firestore.collection('usuarios_sistema');

  Future<bool> _isAdminUser(User? user) async {
    if (user == null) return false;
    if (isAdminApproverUser(user)) return true;

    final profile = await _usuariosSistema.doc(user.uid).get();
    final perfil = normalizePerfil(profile.data()?['perfil'] as String?);
    return perfil == perfilAdministrador;
  }

  Future<void> ensureUserProfileExists(User user, {String? preferredName}) async {
    final email = user.email?.trim().toLowerCase() ?? '';
    final docRef = _usuariosSistema.doc(user.uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      await docRef.set({
        'uid': user.uid,
        'nombre': (preferredName ?? user.displayName ?? email.split('@').first).trim(),
        'correo': email,
        'perfil': isAdminApproverUser(user)
            ? perfilAdministrador
            : perfilOperativoAuxiliar,
        'proyectos': <String>[],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return;
    }

    await docRef.set({
      'uid': user.uid,
      'correo': email,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _generateCode({int length = 8}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _findApprovalCodeDoc(
    String code,
  ) async {
    final query = await _approvalCodes.where('code', isEqualTo: code).limit(1).get();
    if (query.docs.isEmpty) {
      throw Exception('Codigo de aprobacion invalido.');
    }
    return query.docs.first;
  }

  Future<void> _consumeApprovalCode({
    required String code,
    required String usedByUid,
    required String usedByEmail,
  }) async {
    final now = DateTime.now();
    final doc = await _findApprovalCodeDoc(code);
    final data = doc.data() ?? <String, dynamic>{};

    final active = data['active'] == true;
    final usedAt = data['used_at'];
    final expiresRaw = data['expires_at'];
    final expiresAt = expiresRaw is Timestamp ? expiresRaw.toDate() : null;

    if (!active || usedAt != null) {
      throw Exception('El codigo de aprobacion ya fue utilizado o no esta activo.');
    }
    if (expiresAt != null && expiresAt.isBefore(now)) {
      throw Exception('El codigo de aprobacion esta vencido.');
    }

    await _firestore.runTransaction((tx) async {
      final fresh = await tx.get(doc.reference);
      final freshData = fresh.data() ?? <String, dynamic>{};
      final freshActive = freshData['active'] == true;
      final freshUsedAt = freshData['used_at'];
      final freshExpiresRaw = freshData['expires_at'];
      final freshExpiresAt =
          freshExpiresRaw is Timestamp ? freshExpiresRaw.toDate() : null;

      if (!freshActive || freshUsedAt != null) {
        throw Exception('El codigo de aprobacion ya no esta disponible.');
      }
      if (freshExpiresAt != null && freshExpiresAt.isBefore(DateTime.now())) {
        throw Exception('El codigo de aprobacion esta vencido.');
      }

      tx.update(fresh.reference, {
        'active': false,
        'used_at': FieldValue.serverTimestamp(),
        'used_by_uid': usedByUid,
        'used_by_email': usedByEmail,
      });
    });
  }

  Future<String> generateApprovalCode({Duration ttl = const Duration(hours: 72)}) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim().toLowerCase();

    final canGenerate = await _isAdminUser(user);
    if (!canGenerate) {
      throw Exception('Solo un administrador puede generar codigos de aprobacion.');
    }
    if (user == null) {
      throw Exception('Sesion invalida. Inicia sesion nuevamente.');
    }

    final code = _generateCode();
    await _approvalCodes.add({
      'code': code,
      'active': true,
      'created_at': FieldValue.serverTimestamp(),
      'created_by_uid': user.uid,
      'created_by_email': email,
      'expires_at': Timestamp.fromDate(DateTime.now().add(ttl)),
      'used_at': null,
      'used_by_uid': null,
      'used_by_email': null,
    });

    return code;
  }

  Future<void> signInWithEmail(String email, String password) async {
    if (localOnlyAuthMode) {
      if (!hasLocalAdminCredentials) {
        throw Exception(
          'Modo local habilitado sin LOCAL_ADMIN_EMAIL/LOCAL_ADMIN_PASSWORD.',
        );
      }
      if (email.trim().toLowerCase() == localAdminEmail &&
          password == localAdminPassword) {
        return;
      }
      throw Exception('Credenciales locales inválidas.');
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await ensureUserProfileExists(user);
    }
  }

  Future<void> signUpWithEmail(
    String email,
    String password, {
    required String approvalCode,
  }) async {
    if (localOnlyAuthMode) {
      throw Exception('Registro deshabilitado en modo local.');
    }

    final normalizedCode = approvalCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw Exception('Ingresa un codigo de aprobacion valido.');
    }

    // PASO 1: Validar y reservar código ANTES de crear usuario
    // Esto previene usuarios ghost si la transacción falla más adelante
    final codeDoc = await _findApprovalCodeDoc(normalizedCode);
    final codeData = codeDoc.data() ?? <String, dynamic>{};

    if (codeData['active'] != true || codeData['used_at'] != null) {
      throw Exception('El codigo de aprobacion no esta disponible.');
    }

    final expiresRaw = codeData['expires_at'];
    final expiresAt = expiresRaw is Timestamp ? expiresRaw.toDate() : null;
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      throw Exception('El codigo de aprobacion esta vencido.');
    }

    // PASO 2: Crear usuario (código ya validado)
    late UserCredential created;
    try {
      created = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // Si crear usuario falla, código permanece disponible (sin cleanup)
      rethrow;
    }

    final uid = created.user?.uid;
    if (uid == null) {
      throw Exception('No se pudo crear la cuenta de usuario.');
    }

    // PASO 3: Consumir código con usuario ya existente
    try {
      await _consumeApprovalCode(
        code: normalizedCode,
        usedByUid: uid,
        usedByEmail: email.trim().toLowerCase(),
      );
    } catch (e) {
      // Si consumo falla, usuario está en estado coherente (existe, puede login)
      rethrow;
    }

    // PASO 4: Crear perfil (usuario + código ya registrados)
    try {
      await ensureUserProfileExists(
        created.user!,
        preferredName: email.split('@').first,
      );
    } catch (e) {
      // Si perfil falla, usuario puede intentar login después (Estado útil para recuperación)
      rethrow;
    }
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
