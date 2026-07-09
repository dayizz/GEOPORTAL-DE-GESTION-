# IMPL_06_fix_navegacion_import_sesion_limpia

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Corregir tres incidencias funcionales reportadas por usuario:
1. Cambios de vista que se comportan de forma inestable.
2. Gestión en blanco después de importar archivo.
3. Mapa con predios renderizados de forma residual al iniciar una nueva sesión.

## 2. Diagnóstico / contexto actual
Se detectaron tres causas principales:
- El flujo de cierre de sesión en Perfil solo navegaba a login, sin limpiar sesión local ni estado de mapa.
- La tabla de Gestión mantenía paginación/filtros previos al volver desde importación, lo que podía dejar la vista sin filas visibles.
- En carga, al recargar archivos desde BD y no existir archivos, no se limpiaba explícitamente el estado importado del mapa.

## 3. Fases

### Fase 1 - Cierre de sesión real con limpieza de estado
Descripcion: Se implementó logout efectivo para sesión local/remota y limpieza de estado de mapa/importación antes de navegar a login.
Archivos afectados: `lib/features/perfil/presentation/perfil_screen.dart`
Código clave:
- `_cerrarSesion(...)` con `authRepositoryProvider.signOut()`
- Limpieza de `localAuthSessionProvider`, `proyectoActivoProvider`, `gestionProyectoProvider`
- Limpieza de estado importado con `clearImportedMapState(...)`
- Reset de `importacionAsyncProvider`
Tiempo estimado: 20 min
Riesgo: Bajo

### Fase 2 - Estabilización de Gestión post-importación
Descripcion: Se hizo la paginación defensiva para evitar páginas fuera de rango y se resetean filtros/página al recibir navegación post-importación.
Archivos afectados: `lib/features/tabla/presentation/tabla_screen.dart`
Código clave:
- Cálculo de `safePage` y `startRow` con clamp
- Reset de `_busqueda`, `_searchCtrl`, filtros y `_currentPage` al consumir `gestionProyectoProvider`
Tiempo estimado: 20 min
Riesgo: Bajo

### Fase 3 - Limpieza de mapa cuando no hay archivos importados
Descripcion: Al cargar desde BD, si no hay archivos importados, se limpia estado renderizado del mapa para evitar residuos entre sesiones.
Archivos afectados: `lib/features/carga/presentation/carga_archivo_screen.dart`
Código clave:
- En `_cargarArchivosDesdeBD()`: limpieza con `clearImportedMapState(...)` y reset de `importacionAsyncProvider`
- Fallback de proyecto objetivo al proyecto de sesión para no perder contexto al navegar a Gestión
Tiempo estimado: 15 min
Riesgo: Bajo

### Fase 4 - Corrección de selección de navegación
Descripcion: Ajuste de índices de navegación para mantener consistencia en selección de vista activa.
Archivos afectados: `lib/features/perfil/presentation/perfil_screen.dart`, `lib/features/estructura/presentation/estructura_screen.dart`
Código clave:
- `currentIndex` de Perfil corregido a 5
- `currentIndex` de Estructura corregido a 6
Tiempo estimado: 5 min
Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 15 min | Bajo |
| Fase 4 | 5 min | Bajo |
| Total | 60 min | Bajo |

## 5. Criterio de éxito
- Al cerrar sesión, no persiste sesión local activa y se entra correctamente a login.
- Al importar, Gestión muestra filas y no queda en blanco por estado previo de paginación/filtros.
- Al iniciar nueva sesión sin archivos importados, el mapa no renderiza features residuales.
- La navegación lateral mantiene selección coherente de la vista actual.

## 6. Resultado / evidencia
- Cambios aplicados en Perfil, Gestión, Carga y Estructura.
- Validación estática ejecutada sobre archivos modificados: sin errores de compilación.
- Se detectaron solo avisos informativos/deprecaciones preexistentes no bloqueantes.

## 7. Próximo paso
Validación manual de flujo integrado:
1. Cerrar sesión desde Perfil y confirmar redirección estable a login.
2. Iniciar sesión, importar archivo y confirmar visualización en Gestión.
3. Eliminar archivo importado y reiniciar sesión; confirmar que mapa inicia sin predios importados residuales.
