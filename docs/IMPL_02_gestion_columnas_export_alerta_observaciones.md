# IMPL_02 - Ajustes Gestion (columnas, exportacion, alerta liberados, observaciones)

Estado: Implementado
Fecha: 2026-07-01
Rama: main

## 1. Objetivo
Implementar en Gestion:
- eliminacion de columna Oficio,
- separacion de Estado/Municipio en dos columnas,
- nombre de archivo de exportacion XLSX en formato Gestion_Proyecto_Fecha.xlsx,
- registro de Observaciones desde importacion GeoJSON,
- alerta con accion para autocompletar Identificacion, Levantamiento y Negociacion en predios Liberados.

## 2. Diagnostico / contexto actual
Se detecto que:
- la tabla mostraba Estado/Municipio combinado y columna Oficio visible,
- la exportacion XLSX usaba nombre con timestamp,
- no existia mecanismo de validacion masiva para predios liberados incompletos,
- propiedades de observaciones del GeoJSON no se guardaban en el campo usado por Gestion (situacion_social).

## 3. Fases

### Fase 1 - Ajuste de columnas en tabla Gestion
Descripcion:
Se retiro la columna Oficio y se dividio Estado/Municipio en dos columnas separadas (ESTADO y MUNICIPIO), ajustando anchos, encabezados e indices de render.

Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart

Codigo clave:
- _buildTable
- _buildDataRow

Tiempo estimado:
- 45 min

Riesgo:
- Bajo

### Fase 2 - Formato de nombre en exportacion XLSX
Descripcion:
Se implemento nombre de salida con formato Gestion_Proyecto_ddMMyyyy.xlsx para web y desktop/mobile.

Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart

Codigo clave:
- _exportToExcel

Tiempo estimado:
- 20 min

Riesgo:
- Bajo

### Fase 3 - Alerta funcional de liberados incompletos
Descripcion:
Se agrego alerta visual en esquina inferior sobre la tabla con mensaje y botones Aceptar/Cancelar. Aceptar autocompleta los tres campos en true y persiste cambios; Cancelar cierra alerta sin cambios.

Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart

Codigo clave:
- _buildLiberadosAlert
- _autocompletarLiberadosPendientes

Tiempo estimado:
- 60 min

Riesgo:
- Medio (actualizacion masiva de registros)

### Fase 4 - Registro de observaciones desde GeoJSON
Descripcion:
Se amplio el mapeo de importacion para guardar observaciones en situacion_social en creacion y actualizacion de predios.

Archivos afectados:
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- _buildNuevoPredioData
- _buildGestionUpdateData

Tiempo estimado:
- 25 min

Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 45 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 60 min | Medio |
| Fase 4 | 25 min | Bajo |
| Total | 150 min | Bajo/medio |

## 5. Criterio de exito
- Gestion ya no muestra columna Oficio.
- Gestion muestra columnas separadas ESTADO y MUNICIPIO.
- Exportar XLSX genera nombre Gestion_<PROYECTO>_<ddMMyyyy>.xlsx.
- Predios importados con observaciones muestran valor en columna Observaciones.
- Cuando existan predios con estatus Liberado y algun campo faltante entre Identificacion/Levantamiento/Negociacion, se muestra alerta funcional con Aceptar/Cancelar.

## 6. Resultado / evidencia
Se implementaron todos los cambios solicitados y se validaron con analizador estatico en los archivos modificados (sin errores de compilacion, solo avisos informativos de lint ya existentes).

## 7. Proximo paso
Validar en UI con una importacion real:
- confirmar visibilidad de alerta,
- ejecutar Aceptar y verificar persistencia de los tres campos en true,
- exportar XLSX y confirmar nombre de archivo y columnas nuevas.
