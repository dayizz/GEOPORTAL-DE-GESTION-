# IMPL_83 Permisos por proyecto para consulta en geoportal

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo

Restringir lectura/escritura de predios por proyectos asignados al usuario y asegurar que el geoportal de consulta lea solo lo permitido por rol/proyecto.

## 2. Diagnostico / contexto actual

La seguridad por rol ya estaba activa, pero la lectura de predios podia ser amplia para usuarios autenticados. Se requeria cerrar visibilidad por proyecto asignado en `usuarios_sistema.proyectos`.

## 3. Fases

### Fase 1 - Reglas Firestore por proyecto

- Descripcion:
  - Se agregaron funciones para obtener proyectos del perfil y validar acceso por `data.proyecto`.
  - `predios.read` ahora exige proyecto asignado (excepto admin).
  - `predios.create/update` exige proyecto asignado para no-admin.
- Archivos afectados:
  - firestore.rules
- Codigo clave:
  - `userProjects()`
  - `hasAssignedProject(...)`
  - `canReadPredio(...)`
  - `canWritePredio(...)`
- Tiempo estimado: 25 min
- Riesgo: Medio

### Fase 2 - Filtro en backend cliente (repositorio)

- Descripcion:
  - `PrediosRepository.getPredios(...)` recibe `proyecto` y `proyectosPermitidos`.
  - Si hay proyectos permitidos, consulta por proyecto y combina resultados.
  - Si se solicita un proyecto no permitido, responde vacio.
- Archivos afectados:
  - lib/features/predios/data/predios_repository.dart
- Codigo clave:
  - query por `where('proyecto', isEqualTo: ...)`
  - merge/dedupe por id
- Tiempo estimado: 30 min
- Riesgo: Medio

### Fase 3 - Providers de consulta alineados a permisos

- Descripcion:
  - Los providers de lista y mapa usan `currentUserAssignedProjectsProvider` y `canAccessAllProjectsProvider`.
  - Admin mantiene acceso total; no-admin queda filtrado por asignacion.
- Archivos afectados:
  - lib/features/predios/providers/predios_provider.dart
  - lib/features/auth/providers/auth_provider.dart
- Codigo clave:
  - `currentUserAssignedProjectsProvider`
  - `canAccessAllProjectsProvider`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 4 - Index para consultas por proyecto

- Descripcion:
  - Se agrego indice compuesto base para predios por proyecto/fecha.
- Archivos afectados:
  - firestore.indexes.json
- Codigo clave:
  - indice `predios(proyecto ASC, created_at DESC)`
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 25 min | Medio |
| Fase 2 | 30 min | Medio |
| Fase 3 | 20 min | Bajo |
| Fase 4 | 5 min | Bajo |
| Total | 80 min | Medio |

## 5. Criterio de exito

- Usuario no-admin no puede leer predios fuera de sus proyectos asignados.
- Consulta del geoportal trae solo predios permitidos para el usuario.
- Admin conserva acceso completo.

## 6. Resultado / evidencia

- Reglas Firestore aplican control por proyecto.
- Repositorio/provider filtran por proyectos permitidos.
- Indice agregado para consultas por proyecto.

## 7. Proximo paso

Desplegar reglas e indices y validar con 3 perfiles (Admin, Gestor, Operativo) con proyectos distintos para confirmar aislamiento por proyecto.