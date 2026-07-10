# IMPL_75 Endurecimiento de credenciales admin y reglas por UID

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Eliminar credenciales sensibles hardcodeadas en la capa de autenticacion y fortalecer la validacion de administrador en Firestore para reducir riesgo operativo en produccion.

## 2. Diagnostico / contexto actual

La app mantenia valores de admin embebidos en codigo fuente (correo y contrasena local) y reglas de admin por comparacion de email. Esto aumenta riesgo de exposicion y hace fragil la autorizacion si cambia el correo del administrador.

## 3. Fases

### Fase 1 - Parametrizacion de credenciales locales por entorno

- Descripcion:
  - Se reemplazaron constantes hardcodeadas por `String.fromEnvironment` y `bool.fromEnvironment`.
  - Se agrego validacion explicita para evitar modo local sin variables requeridas.
- Archivos afectados:
  - lib/features/auth/providers/auth_provider.dart
  - lib/features/auth/presentation/login_screen.dart
- Codigo clave:
  - `LOCAL_ONLY_AUTH_MODE`
  - `LOCAL_ADMIN_EMAIL`
  - `LOCAL_ADMIN_PASSWORD`
  - `hasLocalAdminCredentials`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2 - Endurecimiento visual de fallback en perfil

- Descripcion:
  - Se removio el fallback de correo admin hardcodeado en UI de perfil.
- Archivos afectados:
  - lib/features/perfil/presentation/perfil_screen.dart
- Codigo clave:
  - Fallback de correo a `Sin correo`.
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 3 - Reglas de administrador por UID/claim

- Descripcion:
  - Se sustituyo validacion por email por validacion de claim admin o UID bootstrap.
  - Se agregaron funciones auxiliares para centralizar el criterio.
- Archivos afectados:
  - firestore.rules
- Codigo clave:
  - `hasAdminClaim()`
  - `isBootstrapAdminUid()`
  - `isAdmin()`
- Tiempo estimado: 15 min
- Riesgo: Medio

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 - Parametrizacion de credenciales | 20 min | Bajo |
| Fase 2 - Ajuste de fallback en perfil | 5 min | Bajo |
| Fase 3 - Reglas admin por UID/claim | 15 min | Medio |
| Total | 40 min | Medio |

## 5. Criterio de exito

- No existen credenciales admin hardcodeadas en autenticacion local.
- El modo local falla de forma explicita si no se configuran variables requeridas.
- La autorizacion admin en Firestore deja de depender de string de email.

## 6. Resultado / evidencia

- `auth_provider.dart` ya no contiene `admin@sao.mx` ni `admin123` como defaults.
- `login_screen.dart` valida configuracion minima antes de permitir bypass local.
- `firestore.rules` aplica admin por claim o UID bootstrap.

## 7. Proximo paso

Desplegar reglas de Firestore actualizadas en produccion:

```bash
firebase deploy --project geoportal-de-gestion --only firestore:rules
```

Y en ejecucion de app, pasar variables de entorno para cualquier uso de modo local (solo entornos no productivos).