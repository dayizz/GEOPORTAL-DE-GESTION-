import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/elemento_composicion.dart';

/// Panel de capas de la hoja activa. Se muestra en orden de z-index
/// invertido (el primero de la lista = el elemento más al frente), que
/// es la convención habitual en editores de este tipo. El arrastre
/// reordena `elementos` (z-index) de la hoja.
class CapasPanel extends StatelessWidget {
  const CapasPanel({
    super.key,
    required this.elementos,
    required this.seleccionadoId,
    required this.onSelect,
    required this.onReorder,
    required this.onToggleVisible,
    required this.onToggleBloqueado,
    required this.onEliminar,
  });

  final List<ElementoComposicion> elementos; // orden z-index, 0 = fondo
  final String? seleccionadoId;
  final ValueChanged<String> onSelect;
  final void Function(int oldIndexZ, int newIndexZ) onReorder;
  final ValueChanged<String> onToggleVisible;
  final ValueChanged<String> onToggleBloqueado;
  final ValueChanged<String> onEliminar;

  @override
  Widget build(BuildContext context) {
    final invertidos = elementos.reversed.toList(growable: false);

    if (invertidos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Sin capas todavía. Usa las herramientas de arriba para agregar elementos.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      itemCount: invertidos.length,
      onReorderItem: (oldDisplayIndex, newDisplayIndex) {
        // El panel muestra el orden invertido; se traduce a índices de
        // z-index reales antes de notificar al editor. `newDisplayIndex`
        // ya viene ajustado para el hueco dejado por `oldDisplayIndex`
        // (comportamiento de `onReorderItem`), a diferencia del extinto
        // `onReorder`.
        final n = invertidos.length;
        final oldZ = n - 1 - oldDisplayIndex;
        final newZ = n - 1 - newDisplayIndex;
        onReorder(oldZ, newZ);
      },
      itemBuilder: (context, index) {
        final elemento = invertidos[index];
        final seleccionado = elemento.id == seleccionadoId;
        return Container(
          key: ValueKey(elemento.id),
          color: seleccionado ? AppColors.primary.withValues(alpha: 0.08) : null,
          child: ListTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -3),
            leading: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_indicator, size: 16, color: AppColors.textLight),
            ),
            title: Text(
              elemento.nombreCapa,
              style: TextStyle(
                fontSize: 12,
                fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelect(elemento.id),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: Icon(
                    elemento.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 15,
                  ),
                  onPressed: () => onToggleVisible(elemento.id),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: Icon(
                    elemento.bloqueado ? Icons.lock_outline : Icons.lock_open_outlined,
                    size: 15,
                  ),
                  onPressed: () => onToggleBloqueado(elemento.id),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.danger),
                  onPressed: () => onEliminar(elemento.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
