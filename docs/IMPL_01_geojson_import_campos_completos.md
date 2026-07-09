# IMPL_01 - Correcciones Importacion GeoJSON (tipo propiedad, estado/municipio, km y liberacion)

Estado: Implementado
Fecha: 2026-07-01
Rama: main

## 1. Objetivo
Corregir la importacion GeoJSON para:
- aceptar todos los tipos de propiedad presentes en origen,
- registrar estado y municipio cuando vengan en campos separados o en columna combinada,
- registrar correctamente km inicio, km fin, km efectivos y tipo de liberacion.

## 2. Diagnostico / contexto actual
Se detectaron tres causas principales en el mapeo de importacion:
- Se usaba busqueda por clave exacta para varios campos, por lo que columnas con espacios, separadores o variantes de nombre no eran detectadas.
- Estado y municipio solo se buscaban como campos separados, sin parseo del formato combinado (ej. estado/municipio).
- Los campos de km y tipo de liberacion no contemplaban suficientes aliases reales de archivo, especialmente variantes con espacios.

## 3. Fases

### Fase 1 - Robustecer deteccion de aliases
Descripcion:
Se agrego busqueda flexible por aliases normalizados (sin acentos, espacios ni signos), para capturar variantes de nombres en propiedades GeoJSON.

Archivos afectados:
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- Nuevo metodo `_pickFlexible(...)`
- Nuevo metodo `_pickDoubleFlexible(...)`

Tiempo estimado:
- 45 min

Riesgo:
- Bajo. Solo amplifica reconocimiento de campos sin cambiar contrato externo.

### Fase 2 - Parseo de estado/municipio combinado
Descripcion:
Se agrego resolucion de estado y municipio con soporte a campo combinado (ej. `estado/municipio`, `edo_mun`, `entidad_municipio`) ademas de campos separados.

Archivos afectados:
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- Nuevo metodo `_resolveEstadoMunicipio(...)`
- Integracion en `_buildNuevoPredioData(...)`
- Integracion en `_buildGestionUpdateData(...)`

Tiempo estimado:
- 35 min

Riesgo:
- Bajo. El parseo solo aplica cuando faltan estado o municipio individuales.

### Fase 3 - Completar mapeo de km y tipo de liberacion
Descripcion:
Se ampliaron aliases para km inicio, km fin, km lineales, km efectivos y tipo de liberacion, incluyendo variantes con espacios y nomenclaturas alternas.

Archivos afectados:
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- Extraccion de km via `_pickDoubleFlexible(...)`
- Extraccion de `tipo_liberacion` via `_pickFlexible(...)`
- Ajuste de deteccion de `tipo_propiedad` para variantes con espacios.

Tiempo estimado:
- 40 min

Riesgo:
- Bajo/medio. Puede capturar mas entradas y por lo tanto poblar mas campos de forma esperada.

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 45 min | Bajo |
| Fase 2 | 35 min | Bajo |
| Fase 3 | 40 min | Bajo/medio |
| Total | 120 min | Bajo/medio |

## 5. Criterio de exito
- Importar un GeoJSON con tipos de propiedad distintos a PRIVADA y verificar persistencia correcta en `tipo_propiedad`.
- Importar un GeoJSON con `estado/municipio` en una sola columna y verificar que ambos campos queden poblados.
- Confirmar persistencia de `km_inicio`, `km_fin`, `km_efectivos` y `tipo_liberacion` en nuevos registros y en actualizacion de existentes cuando aplique.

## 6. Resultado / evidencia
Se implementaron cambios en el flujo de sincronizacion para:
- detectar aliases por coincidencia normalizada,
- parsear estado/municipio combinados,
- cubrir mas variantes de nombres para km y tipo de liberacion,
- evitar que el mapeo dependa unicamente de claves exactas.

Ajustes adicionales tras validacion en entorno:
- Se corrigio el parser de GeoJSON para NO inyectar valores por defecto en 0 cuando no existe dato detectado (antes podia pisar valores reales durante la normalizacion).
- Se habilito sobrescritura controlada en actualizacion de predios existentes para campos criticos de importacion (`tipo_propiedad`, `estado`, `municipio`, `km_inicio`, `km_fin`, `km_lineales`, `km_efectivos`, `tipo_liberacion`).
- Se mejoro conversion numerica para soportar formato de cadenamiento tipo `12+345` y coma decimal.

## 7. Proximo paso
Ejecutar una prueba de importacion con un archivo GeoJSON real del usuario y validar en tabla de gestion que los campos poblados correspondan con el origen.
