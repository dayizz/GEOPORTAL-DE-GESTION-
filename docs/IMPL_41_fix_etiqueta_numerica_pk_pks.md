# IMPL_41 - Fix etiqueta numerica PK/PKS en capa PKS

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Recuperar la visualizacion de la etiqueta numerica de PK/PKS en el mapa cuando el archivo trae el valor en variantes de columna como `PKS`, `pks_num`, `numero_pks`, etc.

## 2. Diagnostico / contexto actual
Tras los ultimos ajustes de normalizacion y render de PKS, algunos archivos dejaron de mostrar texto numerico en etiquetas porque la extraccion priorizaba `PK` pero no cubria variantes frecuentes con llave `PKS`.

## 3. Fases

### Fase 1 - Ampliar aliases en normalizacion de Carga
Descripcion: Se agregaron variantes numericas PKS para generar `pks_label` cuando el archivo no usa `PK` literal.
Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart
Codigo clave:
- `_normalizePksPointFeatures(...)`
- aliases agregados: `pks`, `pks_num`, `pks_numero`, `numero_pk`, `numero_pks`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

### Fase 2 - Ampliar candidatos en renderer de mapa
Descripcion: Se amplio la extraccion de etiqueta en el mapa para leer directamente variantes de PKS numerico desde `properties`.
Archivos afectados:
- lib/features/mapa/presentation/mapa_screen.dart
Codigo clave:
- `_extractPksPointLabel(...)`
- candidatos agregados: `pks`, `PKS`, `pks_num`, `PKS_NUM`, `pks_numero`, `PKS_NUMERO`, `numero_pk`, `NUMERO_PK`, `numero_pks`, `NUMERO_PKS`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Total | 20 min | Bajo |

## 5. Criterio de exito
- Si el archivo trae el dato numerico en columnas tipo `PK` o `PKS`, la etiqueta se muestra en el mapa.
- La etiqueta conserva el contenido del campo sin prefijos artificiales.

## 6. Resultado / evidencia
- Ajuste aplicado en Carga y Mapa para reconocer variantes numericas PK/PKS.

## 7. Proximo paso
Validar con un archivo real que use columna `PKS` numerica y confirmar que se ve la etiqueta en todos los puntos.
