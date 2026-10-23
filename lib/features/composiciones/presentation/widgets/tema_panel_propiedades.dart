import 'package:flutter/material.dart';

/// Estilo exclusivo de los controles; no altera el contenido de la hoja.
class TemaPanelPropiedades extends StatelessWidget {
  const TemaPanelPropiedades({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    const texto = TextStyle(fontFamily: 'Roboto', fontSize: 12, height: 1.3);
    final contenido = texto.copyWith(color: const Color(0xFF6B7280));
    const etiqueta = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w600,
    );
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
