# IMPL_76 Fix perfil correo y visibilidad de aprobacion admin

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Corregir la pantalla de Perfil para mostrar el correo real del usuario autenticado y habilitar correctamente la seccion de aprobacion de usuarios para administradores.

## 2. Diagnostico / contexto actual

Despues del endurecimiento de credenciales, la UI de Perfil seguia priorizando datos locales de `usuariosProvider`, lo que dejaba correo en "No disponible" para sesiones Firebase. Ademas, la visibilidad del bloque de aprobacion dependia solo de `ADMIN_APPROVER_EMAILS`; cuando no se definia en build, el admin no veia la opcion.

## 3. Fases

### Fase 1 - Resolver identidad mostrada en Perfil

- Descripcion:
  - Se agrego fallback de identidad con `currentUserProvider` (Firebase Auth) para nombre/correo.
  - Se unifico inicial del avatar con nombre resuelto.
- Archivos afectados:
  - lib/features/perfil/presentation/perfil_screen.dart
- Codigo clave:
  - `correoMostrado`
  - `nombreMostrado`
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 2 - Admin approver por UID o email

- Descripcion:
  - Se agrego configuracion de UIDs administradores (`ADMIN_APPROVER_UIDS`) con UID bootstrap por default.
  - Se implemento `isAdminApproverUser(User?)` para evaluar por email o UID.
  - Generacion de codigo y visibilidad en Perfil migradas a esta evaluacion.
- Archivos afectados:
  - lib/features/auth/providers/auth_provider.dart
  - lib/features/perfil/presentation/perfil_screen.dart
- Codigo clave:
  - `_adminApproverUidsRaw`
  - `adminApproverUids`
  - `isAdminApproverUser(...)`
- Tiempo estimado: 20 min
- Riesgo: Medio

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 - Identidad en Perfil | 15 min | Bajo |
| Fase 2 - Admin por UID/email | 20 min | Medio |
| Total | 35 min | Medio |

## 5. Criterio de exito

- Perfil muestra correo real de Firebase cuando no hay datos locales.
- El administrador autenticado visualiza el bloque "Aprobacion de Usuarios".
- El boton "Generar codigo de aprobacion" funciona para admin.

## 6. Resultado / evidencia

- Ajuste aplicado en Perfil para correo/nombre efectivos.
- Ajuste aplicado en Auth para deteccion admin por UID/email.

## 7. Proximo paso

Rebuild y deploy de web para reflejar cambios en produccion:

```bash
flutter build web --release
firebase deploy --project geoportal-de-gestion --only hosting
```