# IMPL_79 Fix admin usuarios Firestore y opciones admin

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Corregir que los usuarios nuevos no aparezcan al administrador y habilitar opciones de administracion de usuarios al iniciar sesion como admin.

## 2. Diagnostico / contexto actual

La vista Estructura manejaba usuarios en estado local (memoria), por lo que no reflejaba cuentas reales de Firebase Auth ni persistia cambios entre sesiones.

## 3. Fases

### Fase 1 - Persistencia de perfiles en Firestore

- Descripcion:
  - Se creo flujo para asegurar perfil en `usuarios_sistema` cuando un usuario inicia sesion o se registra.
- Archivos afectados:
  - lib/features/auth/providers/auth_provider.dart
- Codigo clave:
  - `ensureUserProfileExists(...)`
  - llamadas desde `signInWithEmail(...)` y `signUpWithEmail(...)`
- Tiempo estimado: 25 min
- Riesgo: Medio

### Fase 2 - Estructura con stream en tiempo real

- Descripcion:
  - Se reemplazo provider local por stream Firestore para listar usuarios reales.
  - Se movio CRUD de usuarios a operaciones Firestore.
  - Opciones de administracion (agregar/editar/eliminar y codigo) condicionadas a admin autenticado.
- Archivos afectados:
  - lib/features/estructura/presentation/estructura_screen.dart
- Codigo clave:
  - `usuariosCollectionProvider`
  - `usuariosProvider` (StreamProvider)
  - `_saveUsuario(...)`, `_deleteUsuario(...)`
- Tiempo estimado: 35 min
- Riesgo: Medio

### Fase 3 - Perfil alineado al nuevo provider

- Descripcion:
  - Ajuste de `usuarioActualProvider` para resolver usuario por uid/correo desde stream Firestore.
- Archivos afectados:
  - lib/features/perfil/presentation/perfil_screen.dart
- Codigo clave:
  - busqueda por `authUser.uid` y correo normalizado
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 4 - Reglas de seguridad para usuarios_sistema

- Descripcion:
  - Se agregaron reglas para lectura autenticada y escritura por admin o autocreacion/autoupdate controlado del propio usuario.
- Archivos afectados:
  - firestore.rules
- Codigo clave:
  - bloque `match /usuarios_sistema/{uid}`
- Tiempo estimado: 20 min
- Riesgo: Medio

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 25 min | Medio |
| Fase 2 | 35 min | Medio |
| Fase 3 | 10 min | Bajo |
| Fase 4 | 20 min | Medio |
| Total | 90 min | Medio |

## 5. Criterio de exito

- Usuario creado en Auth aparece en Estructura para admin.
- Lista de usuarios persiste y se sincroniza en tiempo real.
- Solo admin ve y usa opciones de administracion.

## 6. Resultado / evidencia

- Estructura consume usuarios desde Firestore.
- Registro/login asegura documento de perfil en `usuarios_sistema`.
- Reglas Firestore actualizadas para la coleccion.

## 7. Proximo paso

Desplegar reglas y hosting para aplicar cambios en produccion y validar con login admin + usuario nuevo.