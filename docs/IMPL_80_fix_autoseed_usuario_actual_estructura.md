# IMPL_80 Fix autoseed usuario actual en Estructura

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Corregir el escenario donde no aparece ningun usuario en Estructura aunque ya existan cuentas en Auth, asegurando al menos el alta automatica del usuario autenticado actual.

## 2. Diagnostico / contexto actual

Se verifico en produccion que `usuarios_sistema` estaba vacia. En ese estado, Estructura no puede mostrar usuarios porque su fuente es Firestore.

## 3. Fases

### Fase 1 - Auto seed de perfil actual

- Descripcion:
  - Se agrego provider para asegurar perfil del usuario autenticado activo en Firestore.
- Archivos afectados:
  - lib/features/auth/providers/auth_provider.dart
- Codigo clave:
  - `ensureCurrentUserProfileProvider`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2 - Lectura robusta de usuarios

- Descripcion:
  - Se elimino `orderBy('created_at')` del stream de usuarios para evitar ocultar documentos sin ese campo.
  - Se dispara la garantia de perfil al cargar Estructura.
- Archivos afectados:
  - lib/features/estructura/presentation/estructura_screen.dart
- Codigo clave:
  - `usuariosProvider` sin `orderBy`
  - `ref.watch(ensureCurrentUserProfileProvider)`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Total | 20 min | Bajo |

## 5. Criterio de exito

- Al abrir Estructura con sesion activa, el perfil del usuario actual queda creado/actualizado en `usuarios_sistema`.
- La lista deja de depender de que todos los documentos tengan `created_at`.

## 6. Resultado / evidencia

- Auto-seed implementado y sin errores de analisis.
- Query de usuarios simplificada y resiliente.

## 7. Proximo paso

Desplegar hosting para publicar el ajuste y validar recarga en Estructura con sesion activa.