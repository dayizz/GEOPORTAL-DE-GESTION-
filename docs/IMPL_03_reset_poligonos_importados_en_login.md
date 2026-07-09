# IMPL_03_reset_poligonos_importados_en_login

Estado: Implementado
Fecha: 2026-07-01
Rama: main

## 1. Objetivo
Evitar que el mapa muestre polígonos importados de sesiones o archivos eliminados al iniciar sesión o al borrar archivos importados.

## 2. Diagnóstico / contexto actual
Se detectó que `importedFeaturesProvider` conservaba estado en memoria entre navegaciones. Al abrir la vista de login o volver al mapa después de iniciar sesión, podían aparecer polígonos precargados aunque el archivo original ya no existiera en la lista de carga.

## 3. Fases

### Fase 1 - Limpieza de estado al entrar y salir de login
Descripcion: Se agregó limpieza explícita del estado de polígonos importados en `LoginScreen` al abrir la pantalla y después de un login exitoso (local y remoto). Luego se extrajo la limpieza a una utilidad reutilizable para validarla con pruebas unitarias.
Archivos afectados: `lib/features/auth/presentation/login_screen.dart`, `lib/features/mapa/providers/mapa_state_cleanup.dart`
Código clave:
- `clearImportedMapState(...)`
Tiempo estimado: 20 min
Riesgo: Bajo (solo limpia estado temporal de UI del mapa)

### Fase 2 - Limpieza al eliminar archivos importados
Descripcion: Se agregó lógica para limpiar el mapa cuando se elimina un archivo que corresponde al set actualmente cargado en mapa. También se limpia siempre al usar eliminar todos.
Archivos afectados: `lib/features/carga/presentation/carga_archivo_screen.dart`
Código clave:
- Detección de archivo activo mediante comparación de referencia y fallback por contenido.
- Limpieza de `importedFeaturesProvider` y reset de `importacionAsyncProvider`.
Tiempo estimado: 25 min
Riesgo: Medio-bajo (comparación por contenido puede coincidir en archivos idénticos; comportamiento esperado en caso de duplicados)

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 25 min | Medio-bajo |
| Total | 45 min | Bajo |

## 5. Criterio de éxito
- Al abrir login, el mapa no conserva polígonos importados previamente.
- Al iniciar sesión, el usuario entra con estado limpio de importaciones.
- Al eliminar un archivo cargado en mapa, sus polígonos dejan de mostrarse.
- Al eliminar todos los archivos, no queda ningún polígono importado visible.

## 6. Resultado / evidencia
- Se aplicaron cambios en pantalla de login para limpieza de estado en init y en rutas de login exitoso.
- La limpieza quedó centralizada en `clearImportedMapState(...)` para evitar divergencias entre login local, remoto e ingreso inicial a la pantalla.
- Se aplicaron cambios en pantalla de carga para limpieza condicional al borrar archivo activo y limpieza total al borrar todos.
- Validación ejecutada: `flutter test test/features/mapa/providers/mapa_state_cleanup_test.dart` con resultado exitoso.
- Verificación estática: sin errores en los archivos modificados.

## 7. Próximo paso
Validar flujo completo manual en navegador:
1. Importar archivo y visualizar en mapa.
2. Eliminar archivo y confirmar desaparición inmediata de polígonos.
3. Cerrar sesión / ir a login y volver a iniciar sesión.
4. Confirmar que el mapa inicia sin polígonos importados residuales.
