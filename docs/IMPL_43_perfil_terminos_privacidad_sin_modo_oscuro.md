# IMPL_43 - Perfil: terminos y privacidad, sin configuracion ni modo oscuro

Estado: Implementado
Fecha: 2026-07-08
Rama: main

## 1. Objetivo
Eliminar la seccion de configuracion y el control de modo oscuro en Perfil, y agregar un boton de "Condiciones y Politica de privacidad" con icono de hoja que despliegue el texto legal solicitado.

## 2. Diagnostico / contexto actual
La pantalla Perfil incluia una seccion "Configuracion" con switch de "Modo Oscuro" que ya no era requerida. Tambien faltaba una seccion legal accesible desde la misma pantalla.

## 3. Fases

### Fase 1 - Retiro de configuracion y modo oscuro
Descripcion: Se elimino la seccion visual de configuracion y el tile/switch de modo oscuro.
Archivos afectados:
- lib/features/perfil/presentation/perfil_screen.dart
Codigo clave:
- Reemplazo del bloque "Configuracion" por seccion "Legal"
- Eliminacion de `_buildModoOscuroTile(...)`
Tiempo estimado:
- 15 min
Riesgo:
- Bajo

### Fase 2 - Nuevo boton legal con icono de hoja
Descripcion: Se agrego un `ListTile` con icono de hoja/documento para abrir terminos y politica de privacidad.
Archivos afectados:
- lib/features/perfil/presentation/perfil_screen.dart
Codigo clave:
- `_buildTerminosPrivacidadTile(...)`
Tiempo estimado:
- 10 min
Riesgo:
- Bajo

### Fase 3 - Dialogo con texto legal completo
Descripcion: Se agrego un dialogo desplazable que muestra el texto de terminos y politicas solicitado por el usuario.
Archivos afectados:
- lib/features/perfil/presentation/perfil_screen.dart
Codigo clave:
- `_terminosPrivacidadTexto`
- `_showTerminosPrivacidadDialog(...)`
Tiempo estimado:
- 15 min
Riesgo:
- Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 15 min | Bajo |
| Total | 40 min | Bajo |

## 5. Criterio de exito
- Ya no se visualizan "Configuracion" ni "Modo Oscuro" en Perfil.
- Existe un boton "Condiciones y Politica de privacidad" con icono de hoja/documento.
- Al pulsarlo, se muestra el texto legal completo solicitado.

## 6. Resultado / evidencia
- Cambio implementado en la pantalla Perfil.
- Validacion estatica sin errores en el archivo modificado.
- Hot restart aplicado para reflejar cambios en runtime.

## 7. Proximo paso
Validar visualmente en la pantalla Perfil que el dialogo sea legible en desktop y web en resoluciones bajas (scroll correcto).
