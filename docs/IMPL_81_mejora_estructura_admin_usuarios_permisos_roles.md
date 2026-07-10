# IMPL_81 Mejora Estructura, administracion de usuarios y permisos por roles

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Mejorar la vista de Estructura, robustecer la administracion de usuarios y definir permisos claros por rol para determinar que puede ver/editar cada tipo de usuario.

## 2. Diagnostico / contexto actual

La vista de Estructura ya consumia usuarios desde Firestore, pero faltaba una experiencia de gestion mas completa (filtros, contexto de permisos) y reglas de rol mas estrictas tanto en UI como en Firestore.

## 3. Fases

### Fase 1 - Roles centralizados en Auth

- Descripcion:
  - Se definieron constantes y helpers de rol.
  - Se agrego resolucion de perfil actual via `usuarios_sistema`.
- Archivos afectados:
  - lib/features/auth/providers/auth_provider.dart
- Codigo clave:
  - `perfilAdministrador`, `perfilGestorProyecto`, `perfilOperativoAuxiliar`
  - `currentUserProfileProvider`, `currentUserPerfilProvider`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2 - Control de acceso por ruta y navegacion

- Descripcion:
  - Se restringio ruta `/estructura` a Admin/Gestor.
  - Se agrego validacion de acceso en menu lateral e inferior.
- Archivos afectados:
  - lib/core/router/app_router.dart
  - lib/shared/widgets/app_scaffold.dart
- Codigo clave:
  - redirect por rol en router
  - `_NavItem.isVisible` en scaffold
- Tiempo estimado: 25 min
- Riesgo: Medio

### Fase 3 - Mejora UX de Estructura y administracion de usuarios

- Descripcion:
  - Se rediseño la pestaña de usuarios con:
    - Tarjeta de permisos por rol
    - Resumen de metricas por rol
    - Busqueda por texto
    - Filtro por rol
  - Admin conserva acciones de alta/edicion/eliminacion.
  - Gestor queda en modo consulta.
- Archivos afectados:
  - lib/features/estructura/presentation/estructura_screen.dart
- Codigo clave:
  - `_buildResumenUsuarios(...)`
  - `_buildFiltros()`
  - `_buildPermissionsCard(...)`
- Tiempo estimado: 35 min
- Riesgo: Medio

### Fase 4 - Endurecimiento de reglas Firestore por rol

- Descripcion:
  - Se incorporo resolucion de rol desde `usuarios_sistema` en rules.
  - Predios/propietarios/archivos:
    - lectura: autenticados
    - create/update: Admin o Gestor
    - delete: solo Admin
  - `usuarios_sistema`:
    - lectura: Admin, Gestor o propio usuario
    - gestion completa: Admin
- Archivos afectados:
  - firestore.rules
- Codigo clave:
  - `userRole()`, `isGestor()`, `canWriteOperationalData()`
- Tiempo estimado: 30 min
- Riesgo: Medio

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 25 min | Medio |
| Fase 3 | 35 min | Medio |
| Fase 4 | 30 min | Medio |
| Total | 110 min | Medio |

## 5. Criterio de exito

- Estructura muestra una UX mas clara para administracion y consulta.
- Las acciones de gestion de usuarios/proyectos no se exponen a perfiles no autorizados.
- Firestore aplica restricciones por rol coherentes con la UI.

## 6. Resultado / evidencia

- UI de Estructura mejorada con panel de permisos, metricas y filtros.
- Restriccion de acceso por rol implementada en router y menu.
- Reglas Firestore ajustadas para operaciones por rol.

## 7. Proximo paso

Desplegar `firestore.rules` y hosting, luego validar manualmente con:
- Admin
- Gestor de proyecto
- Operativo auxiliar
para confirmar visibilidad y acciones por rol.