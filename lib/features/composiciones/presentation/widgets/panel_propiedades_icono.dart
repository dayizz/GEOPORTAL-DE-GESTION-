import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/elemento_composicion.dart';
import '../../utils/iconos_composicion.dart';
import 'color_swatch_picker.dart';
import 'panel_seccion_colapsable.dart';

/// Panel de propiedades para [TipoElemento.icono]: cambiar el icono y su
/// color (la opacidad se ajusta desde el mismo selector de color).
class PanelPropiedadesIcono extends StatelessWidget {
  const PanelPropiedadesIcono({
    super.key,
    required this.elemento,
    required this.onIconoChanged,
    required this.onColorChanged,
  });

  final ElementoComposicion elemento;
  final void Function(String nombre, String etiqueta) onIconoChanged;
  final ValueChanged<String> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelSeccionColapsable(
          titulo: 'Icono',
          icono: Icons.emoji_symbols,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (clave, etiqueta, _) in iconosComposicion)
                  Tooltip(
                    message: etiqueta,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => onIconoChanged(clave, etiqueta),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: clave == elemento.iconoNombre
                                ? AppColors.primary
                                : AppColors.border,
                            width: clave == elemento.iconoNombre ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: IconoComposicion(clave, size: 20, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        PanelSeccionColapsable(
          titulo: 'Color',
          icono: Icons.palette_outlined,
          children: [
            ColorSwatchPicker(
              label: 'Color del icono',
              colorHex: elemento.iconoColorHex,
              onChanged: (v) {
                if (v != null) onColorChanged(v);
              },
            ),
          ],
        ),
      ],
    );
  }
}
