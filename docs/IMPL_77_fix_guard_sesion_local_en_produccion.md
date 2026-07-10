# IMPL_77 Fix guard de sesion local en produccion

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Evitar que en produccion se permitan rutas autenticadas mediante sesion local residual y forzar autenticacion Firebase real para mostrar identidad correcta en Perfil y permisos de admin.

## 2. Diagnostico / contexto actual

La app podia considerar `isLoggedIn` por `localAuthSessionProvider` incluso cuando `localOnlyAuthMode` estaba desactivado. Esto permitia entrar a Perfil sin usuario Firebase en sesion, provocando correo "No disponible" y ausencia de bloque admin.

## 3. Fases

### Fase 1 - Ajuste del guard global de rutas

- Descripcion:
  - Se condiciono el uso de sesion local a `localOnlyAuthMode`.
  - En modo cloud/prod, solo cuenta `FirebaseAuth.currentUser`.
- Archivos afectados:
  - lib/core/router/app_router.dart
- Codigo clave:
  - `canUseLocalSession = localOnlyAuthMode && localSession`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2 - Limpieza explicita de bandera local al login cloud

- Descripcion:
  - En login por Firebase se fuerza `localAuthSessionProvider = false`.
- Archivos afectados:
  - lib/features/auth/presentation/login_screen.dart
- Codigo clave:
  - `ref.read(localAuthSessionProvider.notifier).state = false;`
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 - Guard de rutas | 10 min | Bajo |
| Fase 2 - Limpieza sesion local | 5 min | Bajo |
| Total | 15 min | Bajo |

## 5. Criterio de exito

- En produccion, sin `currentUser` de Firebase no se puede permanecer en rutas privadas.
- Perfil toma identidad real tras login Firebase.
- Seccion de aprobacion admin se habilita para admin autenticado.

## 6. Resultado / evidencia

- Guard corregido para ignorar sesion local fuera de modo local.
- Login cloud limpia estado local residual.

## 7. Proximo paso

Rebuild y deploy de hosting para aplicar el ajuste en produccion:

```bash
flutter build web --release
firebase deploy --project geoportal-de-gestion --only hosting
```