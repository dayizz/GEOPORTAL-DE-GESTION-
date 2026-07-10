# ENDPOINT 01 - API versionada de predios y municipios

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo
Publicar un contrato estable de lectura para el geoportal de consulta, separando la API de visualizacion publica del flujo interno de gestion.

## 2. Diagnostico / contexto actual
El backend de gestion ya exponia `/predios`, pero la consulta necesitaba un contrato mas claro y estable para desacoplarse de rutas ad hoc y evolucionar sin romper el frontend publico.

Ademas, el cliente de consulta requería un catalogo de municipios para filtros y conteos, aunque no exista una fuente cartografica municipal independiente en el backend.

## 3. Fases
### Fase 1 - Versionado del contrato
- Descripcion: se agregaron alias versionados para lectura publica.
- Archivos afectados: `backend/app/main.py`.
- Codigo clave: `GET /api/v1/predios` y `GET /api/v1/municipios`.
- Tiempo estimado: 20 min.
- Riesgo: bajo.

### Fase 2 - Catalogo de municipios
- Descripcion: se construye la respuesta de municipios a partir de los predios almacenados, agrupando por municipio y estado.
- Archivos afectados: `backend/app/main.py`.
- Codigo clave: helper `_municipio_payload(...)` y agrupacion por nombre/estado.
- Tiempo estimado: 20 min.
- Riesgo: medio.

### Fase 3 - Integracion cliente
- Descripcion: `geoportal_consulta` pasa a consumir los endpoints versionados.
- Archivos afectados: `geoportal_consulta/lib/features/mapa/predios_provider.dart`.
- Codigo clave: `GEOPORTAL_GESTION_API_URL` + `api/v1/predios` + `api/v1/municipios`.
- Tiempo estimado: 15 min.
- Riesgo: bajo.

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Versionado del contrato | 20 min | Bajo |
| Catalogo de municipios | 20 min | Medio |
| Integracion cliente | 15 min | Bajo |
| **Total** | **55 min** | **Bajo-Medio** |

## 5. Criterio de exito
- La consulta lee una API versionada y estable.
- La lista de municipios sale de la misma base de predios.
- El contrato no depende de archivos locales ni de rutas temporales.

## 6. Resultado / evidencia
Resultado obtenido:
- `GET /api/v1/predios` devuelve la lista de predios.
- `GET /api/v1/municipios` devuelve un catalogo agrupado por municipio y estado.
- La consulta usa `GEOPORTAL_GESTION_API_URL` para apuntar al backend de gestion.

## 7. Proximo paso
- Publicar la URL real de `GEOPORTAL_GESTION_API_URL` en el entorno de despliegue de consulta y verificar filtros, conteos y focos del mapa.