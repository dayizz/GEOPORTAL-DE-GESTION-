import 'package:flutter/material.dart';

/// Convierte un hex `#RRGGBB` o `#RRGGBBAA` a [Color]. Devuelve `null`
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

/// Paleta reducida de colores preestablecidos para los selectores de
/// color de Composiciones (trazo, relleno, texto, fondo).
const List<String> composicionesPaletaColores = [
  '#1B6CA8', // primary
  '#27AE60', // secondary
  '#E74C3C', // danger
  '#F1C40F', // warning
  '#F39C12', // accent
  '#3498DB', // info
  '#9B59B6', // morado
  '#1A2332', // texto oscuro
  '#6B7A8D', // gris
  '#FFFFFF', // blanco
  '#000000', // negro
  '#BDC3C7', // gris claro
];
