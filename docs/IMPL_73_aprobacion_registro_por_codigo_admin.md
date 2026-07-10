# IMPL_73 - Aprobacion de registro por codigo de administrador

- Estado: Implementado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Permitir que solo usuarios con codigo de aprobacion puedan completar su registro, y que el administrador pueda generar dichos codigos desde la app.

## 2. Diagnostico / contexto actual

El registro con email/password permitia alta directa. No existia flujo de aprobacion previa por administrador ni mecanismo de un solo uso para autorizacion.

## 3. Fases

### Fase 1 - Logica de codigos en autenticacion

- Descripcion:
  - Se agrego gestion de codigos de aprobacion en `AuthRepository`.
  - Se implemento generacion de codigo para admins y consumo transaccional de un solo uso en registro.
  - Si falla validacion de codigo, la cuenta recien creada se elimina para evitar registros no autorizados.
- Archivos afectados:
  - lib/features/auth/providers/auth_provider.dart
- Codigo clave:
  - `generateApprovalCode()`
  - `_consumeApprovalCode(...)`
  - `signUpWithEmail(..., approvalCode: ...)`
- Tiempo estimado: 45 min
- Riesgo: Medio

### Fase 2 - UI de registro y perfil administrador

- Descripcion:
  - Se agrego campo `Codigo de aprobacion` en pantalla de login cuando el modo es registro.
  - Se agrego bloque en Perfil para admins que permite generar codigo y copiarlo al portapapeles.
- Archivos afectados:
  - lib/features/auth/presentation/login_screen.dart
  - lib/features/perfil/presentation/perfil_screen.dart
- Codigo clave:
  - TextFormField `Codigo de aprobacion`
  - Boton `Generar codigo de aprobacion`
- Tiempo estimado: 35 min
- Riesgo: Bajo

### Fase 3 - Reglas de Firestore para codigos

- Descripcion:
  - Se incorporo coleccion `user_approval_codes` en reglas.
  - Solo admin puede crear/eliminar codigos.
  - El consumo del codigo permite update acotado de un solo uso por usuario autenticado.
- Archivos afectados:
  - firestore.rules
- Codigo clave:
  - `function isAdmin()`
  - `match /user_approval_codes/{codeId}`
- Tiempo estimado: 30 min
- Riesgo: Medio

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 - Logica de codigos | 45 min | Medio |
| Fase 2 - UI registro/admin | 35 min | Bajo |
| Fase 3 - Reglas de seguridad | 30 min | Medio |
| Total | 110 min | Medio |

## 5. Criterio de exito

- Un usuario no puede registrarse sin codigo valido.
- Un codigo solo puede usarse una vez.
- El administrador puede generar codigos desde Perfil.
- Reglas de Firestore restringen creacion/eliminacion de codigos a admin.

## 6. Resultado / evidencia

- Registro ahora exige `approvalCode`.
- Perfil incluye accion para generar codigo con TTL.
- Firestore tiene reglas para `user_approval_codes`.

## 7. Proximo paso

Desplegar reglas actualizadas:

```bash
firebase deploy --project geoportal-de-gestion --only firestore:rules
```

Y validar flujo completo:
1. Admin genera codigo.
2. Usuario nuevo se registra con codigo.
3. Reintento con mismo codigo falla por consumo unico.
