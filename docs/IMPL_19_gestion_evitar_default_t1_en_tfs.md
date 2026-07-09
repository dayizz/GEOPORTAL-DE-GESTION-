# IMPL_19_gestion_evitar_default_t1_en_tfs

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Evitar que el campo T/F/S (tramo) se complete automaticamente con `T1` cuando el archivo original no contiene ese dato.

## 2. Diagnostico / contexto actual
Se detectaron defaults forzados a `T1` en varias rutas de importacion/sincronizacion/modelado, lo que provoca datos artificiales en Gestion.

## 3. Fases

### Fase 1 - Eliminar defaults `T1` en importacion/sincronizacion
Descripcion: Se removio el fallback `T1` en mapeo de propiedades y creacion minima de predios.
Archivos afectados:
- lib/features/carga/services/sincronizacion_service.dart
- lib/features/carga/presentation/carga_archivo_screen.dart
Codigo clave:
- `'tramo': ... ?? ''`
- `minData['tramo'] = ''`
Tiempo estimado: 20 min
Riesgo: Medio

### Fase 2 - Eliminar defaults `T1` en repositorio/modelo/local provider
Descripcion: Se ajustaron normalizaciones y construccion de `Predio` para usar vacio cuando no hay tramo.
Archivos afectados:
- lib/features/predios/models/predio.dart
- lib/features/predios/data/predios_repository.dart
- lib/features/predios/providers/local_predios_provider.dart
Codigo clave:
- `tramo: ... ?? ''`
- merge sin `defaultValue: 'T1'`
Tiempo estimado: 20 min
Riesgo: Medio

### Fase 3 - Visualizacion de vacio en Gestion
Descripcion: Se muestra `-` en T/F/S cuando tramo llega vacio.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `final tramoLabel = tramo.trim().isEmpty ? '-' : tramo.trim();`
Tiempo estimado: 10 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Medio |
| Fase 2 | 20 min | Medio |
| Fase 3 | 10 min | Bajo |
| **Total** | **50 min** | **Medio** |

## 5. Criterio de exito
- Nuevas importaciones sin campo tramo NO quedan en `T1` automaticamente.
- En Gestion, T/F/S vacio se visualiza como `-`.

## 6. Resultado / evidencia
- Cambios aplicados en 6 archivos.
- Validacion con `flutter analyze` sin errores de compilacion.
- Hot restart aplicado.

## 7. Proximo paso
Si se requiere corregir historicos ya guardados con `T1` artificial, ejecutar una migracion controlada en base de datos (definir criterio para no afectar `T1` reales).
