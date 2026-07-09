# IMPL_07_ajuste_inicio_vista_gestion_desktop

Estado: Implementado
Fecha: 2026-07-02
Rama: main

## 1. Objetivo
Corregir el desplazamiento excesivo horizontal de la vista Gestión en desktop para que inicie justo después de la línea divisoria del menú lateral.

## 2. Diagnóstico / contexto actual
La vista de Gestión tenía un inset adicional en desktop que volvía a desplazar el contenido, provocando que la tabla iniciara demasiado a la derecha.

## 3. Fases

### Fase 1 - Eliminación del inset duplicado
Descripcion: Se removió el envoltorio con LayoutBuilder y Padding lateral en Gestión para usar directamente el contenedor ya calculado por el scaffold principal.
Archivos afectados: `lib/features/tabla/presentation/tabla_screen.dart`
Código clave:
- Reemplazo de `child: LayoutBuilder(...)` por `child: content`
Tiempo estimado: 10 min
Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Total | 10 min | Bajo |

## 5. Criterio de éxito
- Gestión inicia inmediatamente después de la línea del menú lateral.
- No hay superposición con el NavigationRail.
- Sin errores de compilación en el archivo modificado.

## 6. Resultado / evidencia
- Ajuste aplicado en el layout de Gestión desktop.
- Validación estática ejecutada sobre el archivo modificado sin errores de compilación.

## 7. Próximo paso
Validar visualmente en desktop que la tabla y barra de filtros arrancan al borde correcto del área de contenido y no hay corrimientos adicionales al cambiar de vista.
