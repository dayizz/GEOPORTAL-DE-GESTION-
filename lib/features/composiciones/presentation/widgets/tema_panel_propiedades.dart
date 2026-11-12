import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Estilo exclusivo de los controles; no altera el contenido de la hoja.
class TemaPanelPropiedades extends StatelessWidget {
  const TemaPanelPropiedades({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    // En tema oscuro el texto va en claro (contrario al fondo del panel).
    final oscuro = base.brightness == Brightness.dark;
    final texto = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 12,
      height: 1.3,
      color: AppColors.textPrimary,
    );
    final contenido = texto.copyWith(
      color: oscuro ? AppColors.textPrimary : const Color(0xFF6B7280),
    );
    final etiqueta = texto.copyWith(fontWeight: FontWeight.w600);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme
            .apply(fontFamily: 'Roboto')
            .copyWith(
              bodyLarge: contenido,
              bodyMedium: texto,
              bodySmall: texto,
              titleMedium: contenido,
              titleSmall: etiqueta,
              labelLarge: etiqueta,
              labelMedium: etiqueta,
              labelSmall: etiqueta,
            ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: const OutlineInputBorder(),
          labelStyle: etiqueta,
          floatingLabelStyle: etiqueta,
          hintStyle: contenido,
          prefixStyle: contenido,
          suffixStyle: contenido,
          helperStyle: texto,
          errorStyle: texto,
        ),
        listTileTheme: base.listTileTheme.copyWith(
          dense: true,
          contentPadding: EdgeInsets.zero,
          titleTextStyle: texto.copyWith(color: base.colorScheme.onSurface),
        ),
        chipTheme: base.chipTheme.copyWith(labelStyle: contenido),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(textStyle: etiqueta),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(textStyle: etiqueta),
        ),
      ),
      child: DefaultTextStyle.merge(style: texto, child: child),
    );
  }
}
