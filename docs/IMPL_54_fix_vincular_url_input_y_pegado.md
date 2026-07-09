# IMPL_54 - Fix vincular URL: input y pegado en Gestion

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Corregir el dialogo `Vincular URL de archivo` en Gestion para permitir capturar/pegar correctamente un link.

## 2. Diagnostico / contexto actual
La captura previa de atajos de teclado podia interferir con el pegado nativo en web, provocando que no se insertara la URL.

## 3. Fases

### Fase 1 - Restaurar entrada nativa de texto
Descripcion: Se removio la interceptacion de atajos `Cmd+V/Ctrl+V` para no bloquear el comportamiento nativo del campo.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- Eliminacion de `CallbackShortcuts` alrededor del campo URL
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

### Fase 2 - Mecanismo alterno de pegado
Descripcion: Se agrego boton `Pegar desde portapapeles` en el dialogo para forzar insercion cuando el entorno bloquea el atajo nativo.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- Boton `OutlinedButton.icon` + `_pasteFromClipboard(...)`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

### Fase 3 - Robustez del campo URL
Descripcion: Se reforzo el input como URL (`keyboardType`, `autofillHints`) y se mantuvo validacion `http/https`.
Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart
Codigo clave:
- `keyboardType: TextInputType.url`
- `autofillHints: [AutofillHints.url]`
Tiempo estimado:
- 5 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 5 min | Bajo |
| Total | 25 min | Bajo |

## 5. Criterio de exito
- El campo URL permite captura directa.
- Pegado nativo funciona sin bloqueo.
- Existe opcion de `Pegar desde portapapeles` como respaldo.

## 6. Resultado / evidencia
- Dialogo actualizado en Gestion.
- Validacion estatica sin errores en archivo modificado.

## 7. Proximo paso
Probar en web: abrir `Vincular URL de archivo`, escribir URL manual y pegar desde teclado o boton `Pegar desde portapapeles`.
