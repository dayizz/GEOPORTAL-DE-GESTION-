# IMPL_30 Fix Import GeoJSON Proyecto Campos Tipos

- Estado: Completado
- Fecha: 2026-07-07
- Rama: main

## 1. Objetivo
Corregir errores de importacion GeoJSON en Gestion para:
- evitar que los registros se visualicen en los 4 proyectos cuando pertenecen a uno solo,
- poblar correctamente estado, municipio, km fin y km efectivos,
- registrar y conservar correctamente todos los tipos de propiedad.

## 2. Diagnostico / contexto actual
Se detectaron dos causas principales:
- El filtro por proyecto en la tabla de Gestion estaba deshabilitado, por eso los registros aparecian en cualquier proyecto.
- El mapeo del importador GeoJSON no contemplaba suficientes aliases para proyecto/estado/municipio y tipo de propiedad en escenarios reales de columnas heterogeneas.

## 3. Fases

### Fase 1: Reactivar filtro real por proyecto en Gestion
- Descripcion: Se reactivo la condicion de filtro por proyecto en la tabla.
- Archivos afectados: `lib/features/tabla/presentation/tabla_screen.dart`
- Codigo clave: `_applyFilters` vuelve a evaluar `if (_predioProyecto(p) != _proyectoActual) return false;`
- Tiempo estimado: 10 min
- Riesgo: Bajo.

### Fase 2: Robustecer deteccion de estado/municipio y proyecto
- Descripcion: Se ampliaron aliases y parseo combinado para estado/municipio, y se mejoro resolucion de proyecto con busqueda flexible.
- Archivos afectados: `lib/features/carga/services/sincronizacion_service.dart`
- Codigo clave:
  - `_resolveEstadoMunicipio(...)` con nuevos aliases (`edo`, `entidad_federativa`, `mpio`, etc.)
  - parseo de campo combinado con separadores adicionales (`/`, `,`, `|`, `;`, ` - `)
  - `_resolveProyecto(...)` usando `_pickFlexible(...)`
- Tiempo estimado: 25 min
- Riesgo: Bajo.

### Fase 3: Mejorar resolucion de tipo de propiedad
- Descripcion: Se centralizo y amplio la deteccion de tipo de propiedad para evitar que todo caiga en valor por defecto.
- Archivos afectados: `lib/features/carga/services/sincronizacion_service.dart`
- Codigo clave:
  - Nuevo `_resolveTipoPropiedad(...)` con aliases extendidos (`tenencia`, `clase_propiedad`, etc.)
  - Integracion en alta y actualizacion (`_buildNuevoPredioData`, `_buildGestionUpdateData`, fallback de error)
- Tiempo estimado: 25 min
- Riesgo: Bajo/Medio.

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 25 min | Bajo |
| Fase 3 | 25 min | Bajo/Medio |
| **Total** | **60 min** | **Bajo/Medio** |

## 5. Criterio de exito
- Los predios importados solo se visualizan en el proyecto correspondiente al navegar por pestañas de Gestion.
- Estado, municipio, km fin y km efectivos se almacenan cuando existen en el GeoJSON bajo aliases comunes.
- Se registran predios con tipos de propiedad distintos a PRIVADA sin degradarlos indebidamente.

## 6. Resultado / evidencia
Cambios aplicados en:
- `lib/features/tabla/presentation/tabla_screen.dart`
- `lib/features/carga/services/sincronizacion_service.dart`

Validacion de analisis estatico:
- Sin errores en ambos archivos tras aplicar cambios.

## 7. Proximo paso
Ejecutar una importacion de prueba con el GeoJSON reportado por usuario y validar en Gestion:
- conteo por proyecto,
- columnas estado/municipio/km fin/km efectivos,
- distribucion de tipos de propiedad.