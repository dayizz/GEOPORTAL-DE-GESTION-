import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/elemento_composicion.dart';
import '../../models/hoja.dart';
import '../../utils/capas_carpetas.dart';

/// Diálogo para escribir el nuevo nombre de una capa o carpeta. Devuelve
/// el nombre sin espacios sobrantes, o `null` si se cancela o queda vacío.
Future<String?> pedirNombreCapa(
  BuildContext context,
  String titulo,
  String actual,
) async {
  // Sin TextEditingController propio: desecharlo al cerrar el diálogo
  // fallaba mientras el campo seguía en la animación de salida.
  var texto = actual;
  final nombre = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: TextFormField(
        initialValue: actual,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nombre'),
        onChanged: (v) => texto = v,
        onFieldSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, texto),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  final limpio = nombre?.trim() ?? '';
  return limpio.isEmpty ? null : limpio;
}

/// Panel de capas de la hoja activa. Se muestra en orden de z-index
/// invertido (el primero de la lista = el elemento más al frente), que
/// es la convención habitual en editores de este tipo. El arrastre
/// reordena `elementos` (z-index) de la hoja y, al soltar un elemento
/// bajo una carpeta o entre sus elementos, lo mete en ella (ver
/// [reordenarCapas]).
class CapasPanel extends StatelessWidget {
  const CapasPanel({
    super.key,
    required this.hoja,
    required this.seleccionadoId,
    required this.onSelect,
    required this.onCambiarHoja,
    required this.onToggleVisible,
    required this.onToggleBloqueado,
    required this.onEliminar,
    this.onMenu,
  });

  final Hoja hoja;
  final String? seleccionadoId;
  final ValueChanged<String> onSelect;
  final ValueChanged<Hoja Function(Hoja)> onCambiarHoja;
  final ValueChanged<String> onToggleVisible;
  final ValueChanged<String> onToggleBloqueado;
  final ValueChanged<String> onEliminar;

  /// Clic derecho en el renglón de un elemento (id, posición global).
  final void Function(String id, Offset posicion)? onMenu;

  Future<void> _renombrar(BuildContext context, CarpetaCapas carpeta) async {
    final nombre = await pedirNombreCapa(
      context,
      'Renombrar carpeta',
      carpeta.nombre,
    );
    if (nombre == null) return;
    onCambiarHoja(
      (h) => cambiarCarpeta(h, carpeta.id, (c) => c.copyWith(nombre: nombre)),
    );
  }

  Future<void> _renombrarElemento(
    BuildContext context,
    ElementoComposicion elemento,
  ) async {
    final nombre = await pedirNombreCapa(
      context,
      'Renombrar capa',
      elemento.nombreCapa,
    );
    if (nombre == null) return;
    onCambiarHoja(
      (h) => h.copyWith(
        elementos: [
          for (final e in h.elementos)
            e.id == elemento.id ? e.copyWith(nombreCapa: nombre) : e,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entradas = entradasCapas(hoja);

    if (entradas.isEmpty) {
      return Padding(
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
      itemCount: entradas.length,
      // `newIndex` ya viene ajustado para el hueco dejado por `oldIndex`
      // (comportamiento de `onReorderItem`).
      onReorderItem: (oldIndex, newIndex) =>
          onCambiarHoja((h) => reordenarCapas(h, oldIndex, newIndex)),
      itemBuilder: (context, index) {
        final entrada = entradas[index];
        final carpeta = entrada.carpeta;
        if (carpeta != null) return _renglonCarpeta(context, index, carpeta);
        return _renglonElemento(
          context,
          index,
          entrada.elemento!,
          entrada.enCarpeta,
        );
      },
    );
  }

  Widget _boton(
    IconData icono,
    VoidCallback onPressed, {
    String? tooltip,
    Color? color,
  }) => IconButton(
    tooltip: tooltip,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
    icon: Icon(icono, size: 15, color: color),
    onPressed: onPressed,
  );

  Future<void> _menuCarpeta(
    BuildContext context,
    CarpetaCapas carpeta,
    Offset posicion,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final local = overlay.globalToLocal(posicion);
    PopupMenuItem<String> item(String valor, IconData icono, String texto) =>
        PopupMenuItem(
          value: valor,
          height: 36,
          child: Row(
            children: [
              Icon(icono, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(texto, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        );
    final accion = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        local.dx,
        local.dy,
        overlay.size.width - local.dx,
        overlay.size.height - local.dy,
      ),
      items: [
        item('renombrar', Icons.edit_outlined, 'Renombrar'),
        item(
          'quitar',
          Icons.folder_delete_outlined,
          'Quitar carpeta (conserva sus elementos)',
        ),
      ],
    );
    if (!context.mounted) return;
    switch (accion) {
      case 'renombrar':
        await _renombrar(context, carpeta);
      case 'quitar':
        onCambiarHoja((h) => eliminarCarpeta(h, carpeta.id));
    }
  }

  Widget _renglonCarpeta(
    BuildContext context,
    int index,
    CarpetaCapas carpeta,
  ) {
    final miembros = elementosDeCarpeta(hoja, carpeta.id).toList();
    // Visible/bloqueada si lo están todos sus elementos.
    final visible = miembros.isEmpty || miembros.any((e) => e.visible);
    final bloqueada = miembros.isNotEmpty && miembros.every((e) => e.bloqueado);
    // Soltar encima una capa arrastrada desde su nombre la mete aquí.
    return DragTarget<String>(
      key: ValueKey('carpeta_${carpeta.id}'),
      onWillAcceptWithDetails: (d) => hoja.elementos.any((e) => e.id == d.data),
      onAcceptWithDetails: (d) =>
          onCambiarHoja((h) => meterEnCarpeta(h, d.data, carpeta.id)),
      builder: (context, candidatos, _) {
        final resaltada = candidatos.isNotEmpty;
        return Container(
          decoration: resaltada
              ? BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 1.5),
                )
              : null,
          child: GestureDetector(
            onSecondaryTapDown: (d) =>
                _menuCarpeta(context, carpeta, d.globalPosition),
            child: ListTile(
              // Color en el propio ListTile: un ColoredBox alrededor taparía su
              // resaltado (y Flutter lo marca como error en modo debug).
              tileColor: AppColors.primary.withValues(
                alpha: resaltada ? 0.18 : 0.04,
              ),
              dense: true,
              visualDensity: const VisualDensity(vertical: -3),
              contentPadding: const EdgeInsets.only(left: 4, right: 8),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: AppColors.textLight,
                    ),
                  ),
                  Icon(
                    carpeta.expandida ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                  ),
                  Icon(
                    carpeta.expandida
                        ? Icons.folder_open_outlined
                        : Icons.folder_outlined,
                    size: 17,
                    color: const Color(0xFFE0A526),
                  ),
                ],
              ),
              horizontalTitleGap: 6,
              minLeadingWidth: 0,
              title: Tooltip(
                message: 'Doble clic o clic derecho para renombrar',
                waitDuration: const Duration(milliseconds: 600),
                child: GestureDetector(
                  onDoubleTap: () => _renombrar(context, carpeta),
                  child: Text(
                    miembros.isEmpty
                        ? '${carpeta.nombre} (vacía)'
                        : carpeta.nombre,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              onTap: () => onCambiarHoja(
                (h) => cambiarCarpeta(
                  h,
                  carpeta.id,
                  (c) => c.copyWith(expandida: !c.expandida),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _boton(
                    visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    () => onCambiarHoja(
                      (h) => cambiarElementosDeCarpeta(
                        h,
                        carpeta.id,
                        (e) => e.copyWith(visible: !visible),
                      ),
                    ),
                  ),
                  _boton(
                    bloqueada ? Icons.lock_outline : Icons.lock_open_outlined,
                    () => onCambiarHoja(
                      (h) => cambiarElementosDeCarpeta(
                        h,
                        carpeta.id,
                        (e) => e.copyWith(bloqueado: !bloqueada),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _renglonElemento(
    BuildContext context,
    int index,
    ElementoComposicion elemento,
    bool enCarpeta,
  ) {
    final seleccionado = elemento.id == seleccionadoId;
    return GestureDetector(
      key: ValueKey(elemento.id),
      onSecondaryTapDown: onMenu == null
          ? null
          : (d) => onMenu!(elemento.id, d.globalPosition),
      child: Padding(
        padding: EdgeInsets.only(left: enCarpeta ? 18 : 0),
        child: ListTile(
          tileColor: seleccionado
              ? AppColors.primary.withValues(alpha: 0.08)
              : null,
          dense: true,
          visualDensity: const VisualDensity(vertical: -3),
          // La agarradera reordena; el nombre se arrastra para soltarlo
          // encima de una carpeta.
          leading: ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_indicator,
              size: 16,
              color: AppColors.textLight,
            ),
          ),
          title: Tooltip(
            message: 'Doble clic o clic derecho para renombrar',
            waitDuration: const Duration(milliseconds: 600),
            child: GestureDetector(
              onDoubleTap: () => _renombrarElemento(context, elemento),
              child: hoja.carpetas.isEmpty
                  ? _nombreElemento(elemento, seleccionado)
                  : Draggable<String>(
                      data: elemento.id,
                      dragAnchorStrategy: pointerDragAnchorStrategy,
                      feedback: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(6),
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.drive_file_move_outline,
                                size: 16,
                                color: Color(0xFFE0A526),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                elemento.nombreCapa,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _nombreElemento(elemento, seleccionado),
                      ),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: _nombreElemento(elemento, seleccionado),
                      ),
                    ),
            ),
          ),
          onTap: () => onSelect(elemento.id),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _boton(
                elemento.visible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                () => onToggleVisible(elemento.id),
              ),
              _boton(
                elemento.bloqueado
                    ? Icons.lock_outline
                    : Icons.lock_open_outlined,
                () => onToggleBloqueado(elemento.id),
              ),
              _boton(
                Icons.delete_outline,
                () => onEliminar(elemento.id),
                color: AppColors.danger,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nombreElemento(ElementoComposicion elemento, bool seleccionado) =>
      Text(
        elemento.nombreCapa,
        style: TextStyle(
          fontSize: 12,
          fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w400,
        ),
        overflow: TextOverflow.ellipsis,
      );
}
