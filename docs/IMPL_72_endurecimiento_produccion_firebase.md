# IMPL_72 - Endurecimiento produccion Firebase

- Estado: Implementado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Dejar la app con base operativa para producción sobre Firebase, eliminando bypass de autenticación y versionando reglas de seguridad/índices para despliegue reproducible.

## 2. Diagnóstico / contexto actual

La migración a Firebase estaba completada funcionalmente, pero faltaban piezas de endurecimiento:
- Bypass local admin aún presente en proveedor de auth.
- Sin `firestore.rules` ni `firestore.indexes.json` en repositorio.
- `firebase.json` sin sección de Firestore/Storage para deploy de seguridad.

## 3. Fases

### Fase 1 - Eliminar bypass de autenticación

- Descripción:
  - Se removió la ruta que permitía acceso con credenciales hardcodeadas fuera de FirebaseAuth.
- Archivos afectados:
  - lib/features/auth/providers/auth_provider.dart
- Código clave:
  - Se eliminan retornos anticipados para `localAdminEmail/localAdminPassword`.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2 - Reglas e índices versionados

- Descripción:
  - Se agregaron reglas de Firestore con acceso autenticado y validación mínima por colección crítica.
  - Se agregaron índices versionados (estructura base).
  - Se agregaron reglas de Storage (denegación total por defecto).
- Archivos afectados:
  - firestore.rules
  - firestore.indexes.json
  - storage.rules
- Código clave:
  - `isSignedIn()` en reglas y `match` para `predios`, `propietarios`, `archivos_geojson`.
- Tiempo estimado: 25 min
- Riesgo: Medio

### Fase 3 - Pipeline de despliegue Firebase

- Descripción:
  - `firebase.json` actualizado para desplegar hosting + reglas + índices.
- Archivos afectados:
  - firebase.json
- Código clave:
  - Secciones: `firestore.rules`, `firestore.indexes`, `storage.rules`.
- Tiempo estimado: 15 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 - Auth sin bypass | 10 min | Bajo |
| Fase 2 - Reglas e índices | 25 min | Medio |
| Fase 3 - Deploy config | 15 min | Bajo |
| Total | 50 min | Medio |

## 5. Criterio de éxito

- No existe bypass local de autenticación en flujo cloud.
- Reglas/índices de Firestore están en git.
- `firebase deploy` aplica también seguridad y no solo hosting.

## 6. Resultado / evidencia

- Bypass eliminado en auth provider.
- Archivos de seguridad creados y versionados.
- `firebase.json` extendido con `firestore` y `storage`.

## 7. Próximo paso

Aplicar despliegue completo de producción:

```bash
firebase deploy --only hosting,firestore:rules,firestore:indexes,storage
```

Y validar en consola Firebase:
- Authentication (método Email/Password activo)
- Firestore rules publicadas
- Firestore indexes en estado `Enabled`
- App Check habilitado para web
