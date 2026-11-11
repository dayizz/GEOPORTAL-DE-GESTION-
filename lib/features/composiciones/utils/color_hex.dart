import 'package:flutter/material.dart';

/// Convierte un hex `#RRGGBB` o `#AARRGGBB` a [Color]. Devuelve `null`
/// para `null`/vacío (usado como "sin color" en fondo/relleno).
Color? colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  final intValue = int.tryParse(value, radix: 16);
  if (intValue == null) return null;
  return Color(intValue);
}

/// Convierte un [Color] a hex `#RRGGBB` (sin canal alfa, ya que los
/// colores de trazo/relleno de Composiciones son siempre opacos salvo
/// que se use `colorToHexConAlpha`).
String colorToHex(Color color) {
  final value = ((color.a * 255).round() << 24) |
      ((color.r * 255).round() << 16) |
      ((color.g * 255).round() << 8) |
      (color.b * 255).round();
  return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Convierte un [Color] a hex `#AARRGGBB` conservando su opacidad.
String colorToHexConAlpha(Color color) {
  final value = ((color.a * 255).round() << 24) |
      ((color.r * 255).round() << 16) |
      ((color.g * 255).round() << 8) |
      (color.b * 255).round();
  return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// Hex totalmente transparente: "sin color" para propiedades que no
/// admiten `null` (porque `null` ya significa su color por defecto).
const String hexSinColor = '#00000000';

/// `true` si [hex] es `null` o un color totalmente transparente.
bool esSinColor(String? hex) {
  final color = colorFromHex(hex);
  return color == null || color.a == 0;
}

/// Multiplica la opacidad propia de [color] (canal alfa del hex) por
/// [opacidad], para propiedades que además guardan la opacidad aparte.
Color aplicarOpacidad(Color color, double opacidad) =>
    color.withValues(alpha: color.a * opacidad.clamp(0, 1));
