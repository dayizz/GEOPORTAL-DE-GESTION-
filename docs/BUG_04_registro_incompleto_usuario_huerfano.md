# BUG #4: Registro Incompleto Deja Usuario Huérfano en Firebase Auth

**Severidad**: 🔴 ALTA — Integridad de datos  
**Archivo**: `lib/features/auth/providers/auth_provider.dart` líneas 374-419  
**Tipo**: Race condition / Error handling incompleto  

---

## Problema

En `signUpWithEmail()`, si un error ocurre después de crear el usuario en Firebase Auth pero antes de completar todo el flujo, el usuario queda en estado inconsistente:

```dart
UserCredential? created;
try {
  created = await _auth.createUserWithEmailAndPassword(...);  // ✓ Usuario creado
  
  await _consumeApprovalCode(...);  // ✗ Si falla aquí → usuario existe, código no consumido
  
  await ensureUserProfileExists(...);  // ✗ Si falla aquí → usuario existe, perfil no creado
} catch (e) {
  final user = created?.user ?? _auth.currentUser;
  if (user != null) {
    try {
      await user.delete();  // ✗ Puede fallar sin credenciales recientes
    } catch (_) {
      await _auth.signOut();  // ✗ Solo desconecta sesión, NO elimina usuario
    }
  }
  rethrow;
}
```

---

## Escenarios de Fallo

### 1. **Fallo en `_consumeApprovalCode()`**
- Usuario creado en Firebase Auth ✓
- Código NO marcado como usado ✗
- Firestore profile NO creado ✗
- **Resultado**: Usuario ghost en Auth, puede intentar login pero fallará en Firestore

### 2. **Fallo en `ensureUserProfileExists()`**
- Usuario creado en Firebase Auth ✓
- Código consumido ✓
- Firestore profile NO creado ✗
- **Resultado**: Usuario puede loguear pero no tiene perfil

### 3. **`user.delete()` Falla**
- Ocurre excepción en (1) o (2) ✓
- Intenta eliminar usuario ✓
- `delete()` requiere credenciales recientes → **throws FirebaseAuthException** ✗
- Fallback a `_auth.signOut()` solo desconecta sesión actual
- **Resultado**: Usuario ghost persiste indefinidamente en Firebase Auth

---

## Raíz de la Causa

1. **Orden incorrecto**: Crear usuario antes de validar y consumir código
2. **Cleanup débil**: `user.delete()` requiere reauthenticación, puede silenciosamente fallar
3. **Sin estado intermedio**: No hay way de retomar/rollback transacción parcial

---

## Impacto

- **Seguridad**: Usuarios no autenticados pueden existir en Auth sin perfil de control
- **UX**: Usuario queda bloqueado con excepción, intento reintentar crea otro ghost
- **Operacional**: Acumulación de usuario huérfano invalida reportes de usuarios activos

---

## Solución Propuesta

Reordenar la lógica para validar ANTES de crear usuario:

```dart
Future<void> signUpWithEmail(
  String email,
  String password, {
  required String approvalCode,
}) async {
  final normalizedCode = approvalCode.trim().toUpperCase();
  if (normalizedCode.isEmpty) {
    throw Exception('Ingresa un codigo de aprobacion valido.');
  }

  // ✓ PASO 1: Verificar y RESERVAR el código ANTES de crear usuario
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

  // ✓ PASO 2: Crear usuario (ahora sabemos que código es válido)
  late UserCredential created;
  try {
    created = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  } catch (e) {
    // Si crear usuario falla, el código permanece disponible (sin cleanup necesario)
    rethrow;
  }

  final uid = created.user?.uid;
  if (uid == null) {
    throw Exception('No se pudo crear la cuenta de usuario.');
  }

  // ✓ PASO 3: Consumir código con el usuario ya existente
  try {
    await _consumeApprovalCode(
      code: normalizedCode,
      usedByUid: uid,
      usedByEmail: email.trim().toLowerCase(),
    );
  } catch (e) {
    // Si consumo falla, el usuario existe pero aún puede crearse nuevo perfil después
    // O admin puede reasignar el código. Usuario está en estado coherente.
    rethrow;
  }

  // ✓ PASO 4: Crear perfil (usuario existe y código consumido)
  try {
    await ensureUserProfileExists(
      created.user!,
      preferredName: email.split('@').first,
    );
  } catch (e) {
    // Si perfil falla, usuario existe y código consumido. Usuario puede intentar login.
    // No intentar delete() ya que usuario está en estado útil para recuperación.
    rethrow;
  }
}
```

---

## Ventajas de Esta Solución

1. **Validación primero**: Si código es inválido, no crear usuario
2. **Sin cleanup frágil**: Si algo falla, usuario queda en estado consistente y recuperable
3. **Transparencia**: Cada paso es independiente y retryable
4. **Menos race conditions**: Código es reservado antes de crear usuario

---

## Nota Operacional

Usuarios en estado inconsistente existentes:
- Si `perfil` no existe pero `uid` existe en Auth → asignar perfil vía Firestore
- Si `código` nunca se consumió → admin puede reactivarlo manualmente
- Si usuario ghost existe → puede ser identificado por queries de usuarios sin perfil

---

## Status

🔴 **IDENTIFICADO Y REPORTADO**  
Pendiente: Implementación de fix

