# IMPL_34 - Inferencia de Estado/Municipio desde Clave TSNL

- Estado: Implementado
- Fecha: 2026-07-07
- Rama: main

## 1. Objetivo
Completar los campos `estado` y `municipio` cuando el GeoJSON no los trae como columnas explicitas, usando la `clave_catastral` como fuente de inferencia para predios del proyecto TSNL.

## 2. Diagnostico / contexto actual
- Los registros nuevos seguian guardandose sin `estado` ni `municipio`.
- La tabla de Gestion si renderiza esos campos, pero el backend no los estaba persistiendo y muchos registros historicos ya quedaron vacios.
- El archivo fuente si trae una `CLAVE` consistente con patron tipo `SNL-SLV-012`, donde el segundo token codifica municipio.

## 3. Fases

### Fase 1 - Inferencia en sincronizacion GeoJSON
- Descripcion: Se agrego inferencia local desde `clave_catastral` para completar `estado/municipio` cuando no existen en `properties`.
- Archivos afectados:
  - lib/features/carga/services/sincronizacion_service.dart
- Codigo clave:
  - `_inferEstadoMunicipioDesdeClave(...)`
  - fallback dentro de `_resolveEstadoMunicipio(...)`
- Tiempo estimado: 25 min
- Riesgo: Bajo

### Fase 2 - Persistencia backend con fallback por clave
- Descripcion: El backend ahora infiere y guarda `estado/municipio` desde la clave si llegan vacios.
- Archivos afectados:
  - backend/app/main.py
- Codigo clave:
  - `_infer_estado_municipio_from_clave(...)`
  - integracion en `_normalize_predio(...)`
- Tiempo estimado: 25 min
- Riesgo: Bajo

### Fase 3 - Visualizacion de historicos ya importados
- Descripcion: Se agrego fallback de lectura en el modelo `Predio` para que la tabla muestre `estado/municipio` aun en registros viejos que ya se guardaron vacios.
- Archivos afectados:
  - lib/features/predios/models/predio.dart
- Codigo clave:
  - `inferEstadoMunicipioDesdeClave(...)`
  - fallback en `estado` y `municipio` dentro de `Predio.fromMap(...)`
- Tiempo estimado: 20 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 25 min | Bajo |
| Fase 2 | 25 min | Bajo |
| Fase 3 | 20 min | Bajo |
| Total | 70 min | Bajo |

## 5. Criterio de exito
- Gestion muestra `estado = Nuevo Leon` y el `municipio` correcto para claves TSNL conocidas aunque el archivo no traiga esas columnas.
- Nuevas importaciones persisten ambos campos en backend.
- Registros historicos se visualizan correctamente sin requerir reimportacion inmediata.

## 6. Resultado / evidencia
- Se implemento inferencia por clave en sincronizacion, backend y lectura de modelo.
- Validacion estatica prevista sobre los archivos modificados.

## 7. Proximo paso
Reiniciar backend y refrescar la vista de Gestion para confirmar que filas como `SNL-SLV-*`, `SNL-VIL-*`, `SNL-BUS-*` y `SNL-LAM-*` muestran ya `estado` y `municipio`.