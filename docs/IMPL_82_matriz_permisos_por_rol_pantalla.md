# IMPL_82 Matriz de permisos por rol y pantalla

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Definir e implementar una matriz clara de permisos por rol para todas las pantallas clave del geoportal.

## 2. Diagnostico / contexto actual

Existian controles parciales por rol (principalmente en Estructura y Archivos), pero faltaba una matriz consolidada para rutas de consulta y rutas de alta/edicion.

## 3. Fases

### Fase 1 - Matriz centralizada en codigo

- Descripcion:
  - Se incorporo helper `canAccessRouteByPerfil(route, perfil)` para decisiones unificadas.
- Archivos afectados:
  - lib/features/auth/providers/auth_provider.dart
- Codigo clave:
  - `canManageOperationalData(...)`
  - `canAccessRouteByPerfil(...)`
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 2 - Aplicacion en router

- Descripcion:
  - Se forzo redirect a `/mapa` cuando un rol no tiene acceso a la ruta solicitada.
- Archivos afectados:
  - lib/core/router/app_router.dart
- Codigo clave:
  - guard central con `canAccessRouteByPerfil(...)`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3 - Aplicacion en navegacion

- Descripcion:
  - Se alineo visibilidad/accion del menu principal con la misma matriz de permisos.
- Archivos afectados:
  - lib/shared/widgets/app_scaffold.dart
- Codigo clave:
  - `_NavItem.isVisible` usando `canAccessRouteByPerfil(...)`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 10 min | Bajo |
| Total | 35 min | Bajo |

## 5. Criterio de exito

- Un usuario no autorizado no puede abrir rutas restringidas via URL directa.
- El menu no ofrece secciones restringidas al rol.
- La logica de permisos se mantiene en un solo punto.

## 6. Matriz de permisos (UI/Router)

| Pantalla / Ruta | Administrador | Gestor de proyecto | Operativo auxiliar |
|---|---|---|---|
| Mapa (`/mapa`) | Ver | Ver | Ver |
| Balance (`/balance`) | Ver | Ver | Ver |
| Archivos (`/carga`) | Ver/usar | Ver/usar | Sin acceso |
| Gestion (`/tabla`) | Ver | Ver | Ver |
| Reportes (`/reportes`) | Ver | Ver | Ver |
| Perfil (`/perfil`) | Ver | Ver | Ver |
| Estructura (`/estructura`) | Ver/gestionar | Ver (consulta) | Sin acceso |
| Catalogo proyectos (`/proyectos`) | Ver/gestionar | Ver/gestionar | Sin acceso |
| Rutas de alta/edicion (`*/nuevo`, `*/editar`) | Permitido | Permitido | Restringido |

## 7. Resultado / evidencia

- Matriz implementada en providers, router y scaffold.
- Restriccion consistente al navegar por menu y por URL directa.

## 8. Proximo paso

Validar manualmente con 3 cuentas (Admin, Gestor, Operativo) que:
- menu visible coincide con rol,
- URL directa redirige cuando no hay permiso,
- operaciones de alta/edicion bloquean al Operativo.