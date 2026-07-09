# IMPL_05_eliminar_archivo_actual_de_gestion_y_mapa

Estado: Implementado
Fecha: 2026-07-01
Rama: main

## 1. Objetivo
Al eliminar el archivo importado actual, borrar también su impacto en Gestión y en el mapa para evitar residuos de datos.

## 2. Diagnóstico / contexto actual
La eliminación de archivo en carga removía el registro del archivo y limpiaba parcialmente el mapa, pero no eliminaba sistemáticamente los predios asociados en Gestión.

## 3. Fases

### Fase 1 - Eliminación local por claves catastrales
Descripcion: Se añadió método para remover predios locales por conjunto de claves catastrales.
Archivos afectados: `lib/features/predios/providers/local_predios_provider.dart`
Código clave:
- `removeByClaves(Set<String> clavesNormalizadas)`
Tiempo estimado: 10 min
Riesgo: Bajo

### Fase 2 - Eliminación integral al borrar archivo(s)
Descripcion: Se amplió el flujo de eliminación de archivo en carga para extraer claves desde features, borrar predios asociados en Gestión (local/remoto), limpiar mapa importado y refrescar providers de tabla/mapa. La extracción se movió a una utilidad para soportar variantes razonables de `clave catastral` y validarla con pruebas.
Archivos afectados: `lib/features/carga/presentation/carga_archivo_screen.dart`, `lib/features/carga/utils/imported_file_cleanup.dart`
Código clave:
- `extractClavesFromFeatures(...)`
- `_eliminarPrediosDeGestionPorClaves(...)`
- Integración en `_eliminarArchivo(...)` y `_eliminarTodos(...)`
Tiempo estimado: 30 min
Riesgo: Medio-bajo (depende de calidad de clave_catastral en archivo)

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 30 min | Medio-bajo |
| Total | 40 min | Medio-bajo |

## 5. Criterio de éxito
- Eliminar archivo actual quita sus polígonos del mapa.
- Eliminar archivo actual borra en Gestión los predios vinculados por clave catastral.
- Eliminar todos aplica el mismo criterio para todos los archivos cargados.

## 6. Resultado / evidencia
- Implementación aplicada en carga y provider local de predios.
- Se robusteció la extracción de claves para reconocer variantes con espacios o separadores en el nombre del campo.
- Validaciones ejecutadas:
	- `flutter test test/features/carga/utils/imported_file_cleanup_test.dart`
	- `flutter test test/features/predios/providers/local_predios_provider_test.dart`
- Resultado exitoso en ambas pruebas.
- Validación estática sin errores en archivos modificados.

## 7. Próximo paso
Probar flujo manual:
1. Importar archivo con claves catastrales conocidas.
2. Verificar presencia en tabla Gestión y en mapa.
3. Eliminar archivo.
4. Confirmar desaparición de predios en Gestión y polígonos en mapa.
