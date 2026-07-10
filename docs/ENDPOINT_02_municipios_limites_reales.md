# ENDPOINT 02 - Municipios con limites reales

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo
Restaurar la capa de municipios para el geoportal de consulta usando una fuente real de geometria municipal centralizada en `geoportal-lddv`, sin recurrir a geometria derivada de predios.

## 2. Diagnostico / contexto actual
La version anterior del endpoint de municipios devolvia un catalogo derivado de predios. Eso servia para filtros, pero no para dibujar limites municipales reales en el mapa.

La geometria real existia como GeoJSON en el workspace de consulta y fue centralizada en el backend de gestion para que la consulta siga siendo un cliente remoto sin datos locales propios.

## 3. Fases
### Fase 1 - Centralizacion de la fuente
- Descripcion: se copio el GeoJSON municipal al backend de gestion.
- Archivos afectados: `backend/data/municipios.geojson`.
- Codigo clave: origen unico de limites municipales.
- Tiempo estimado: 10 min.
- Riesgo: bajo.

### Fase 2 - Lectura y normalizacion
- Descripcion: se agrego un lector de GeoJSON que normaliza cada feature a `id`, `nombre`, `estado` y `geometry`.
- Archivos afectados: `backend/app/main.py`.
- Codigo clave: `_read_municipios_geojson()`.
- Tiempo estimado: 20 min.
- Riesgo: medio.

### Fase 3 - Contrato publico
- Descripcion: `GET /municipios` y `GET /api/v1/municipios` ahora retornan los limites reales para la consulta.
- Archivos afectados: `backend/app/main.py`.
- Codigo clave: endpoints versionados y lectura desde `municipios.geojson`.
- Tiempo estimado: 10 min.
- Riesgo: bajo.

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Centralizacion | 10 min | Bajo |
| Lectura / normalizacion | 20 min | Medio |
| Contrato publico | 10 min | Bajo |
| **Total** | **40 min** | **Bajo-Medio** |

## 5. Criterio de exito
- La consulta recibe limites municipales reales desde el backend de gestion.
- No se usan geometrías derivadas de predios para la capa municipal.
- Si el GeoJSON falta o es invalido, el endpoint responde vacio en vez de inventar geometria.

## 6. Resultado / evidencia
- Se incorporo la fuente `municipios.geojson` al backend.
- `GET /api/v1/municipios` deja de depender del catalogo derivado.
- La capa municipal en consulta puede volver a dibujarse con geometria real.

## 7. Proximo paso
Verificar en el mapa de consulta que la capa municipal se renderiza con los limites reales y revisar si hace falta una simplificacion adicional para performance.
