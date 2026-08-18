import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/color_hex.dart';

/// Rueda de matiz/saturación (ángulo = matiz, distancia al centro =
/// saturación) + control de brillo aparte, para elegir cualquier tono en
/// vez de limitarse a la paleta fija de [ColorSwatchPicker]. No depende de
/// ningún paquete de color (no hay ninguno instalado en el proyecto):
/// la rueda se dibuja con un `SweepGradient` (matiz) + un `RadialGradient`
/// blanco->transparente encima (saturación), el mismo truco declarativo
/// que usan la mayoría de los selectores HSV sin necesidad de pintar
/// pixel a pixel.
Future<String?> showColorWheelDialog(BuildContext context, {String? initialHex}) {
  var hsv = HSVColor.fromColor(colorFromHex(initialHex) ?? const Color(0xFF1B6CA8));
  final hexCtrl = TextEditingController(text: colorToHex(hsv.toColor()).substring(1));

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          void actualizarDesdeRueda(HSVColor nuevo) {
            setState(() {
              hsv = nuevo;
              hexCtrl.text = colorToHex(hsv.toColor()).substring(1);
            });
          }

          void actualizarDesdeHex(String value) {
            final color = colorFromHex(value.startsWith('#') ? value : '#$value');
            if (color != null) setState(() => hsv = HSVColor.fromColor(color));
          }

          return AlertDialog(
            title: const Text('Selecciona un color'),
            content: SizedBox(
              width: 240,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RuedaColor(
                    size: 220,
                    hue: hsv.hue,
                    saturation: hsv.saturation,
                    onChanged: (h, s) => actualizarDesdeRueda(hsv.withHue(h).withSaturation(s)),
                  ),
                  const SizedBox(height: 18),
                  _BarraBrillo(
                    hue: hsv.hue,
                    saturation: hsv.saturation,
                    value: hsv.value,
                    onChanged: (v) => actualizarDesdeRueda(hsv.withValue(v)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: hsv.toColor(),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hexCtrl,
                          maxLength: 6,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Hex',
                            prefixText: '#',
                            isDense: true,
                            counterText: '',
                          ),
                          onChanged: actualizarDesdeHex,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, colorToHex(hsv.toColor())),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Botón compacto (para insertar junto a la paleta de [ColorSwatchPicker])
/// que abre [showColorWheelDialog] y reporta el resultado.
class BotonRuedaColor extends StatelessWidget {
  const BotonRuedaColor({super.key, required this.colorHex, required this.onChanged});

  final String? colorHex;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Más tonos',
      child: GestureDetector(
        onTap: () async {
          final resultado = await showColorWheelDialog(context, initialHex: colorHex);
          if (resultado != null) onChanged(resultado);
        },
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
            ),
            border: Border.fromBorderSide(BorderSide(color: Colors.black26)),
          ),
          child: const Icon(Icons.add, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

class _RuedaColor extends StatelessWidget {
  const _RuedaColor({
    required this.size,
    required this.hue,
    required this.saturation,
    required this.onChanged,
  });

  final double size;
  final double hue;
  final double saturation;
  final void Function(double hue, double saturation) onChanged;

  void _actualizarDesdePosicion(Offset local) {
    final center = Offset(size / 2, size / 2);
    final radius = size / 2;
    final delta = local - center;
    final distancia = delta.distance.clamp(0.0, radius);
    var angulo = math.atan2(delta.dy, delta.dx) * 180 / math.pi;
    if (angulo < 0) angulo += 360;
    onChanged(angulo, distancia / radius);
  }

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final anguloRad = hue * math.pi / 180;
    final distancia = saturation * radius;
    final thumb = Offset(radius + distancia * math.cos(anguloRad), radius + distancia * math.sin(anguloRad));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _actualizarDesdePosicion(details.localPosition),
      onPanStart: (details) => _actualizarDesdePosicion(details.localPosition),
      onPanUpdate: (details) => _actualizarDesdePosicion(details.localPosition),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white, Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: thumb.dx - 9,
              top: thumb.dy - 9,
              child: IgnorePointer(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HSVColor.fromAHSV(1, hue, saturation, 1).toColor(),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraBrillo extends StatelessWidget {
  const _BarraBrillo({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final ValueChanged<double> onChanged;

  static const _ancho = 220.0;
  static const _alto = 20.0;

  void _actualizarDesdePosicion(double dx) {
    onChanged((dx / _ancho).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final colorPleno = HSVColor.fromAHSV(1, hue, saturation, 1).toColor();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _actualizarDesdePosicion(details.localPosition.dx),
      onPanStart: (details) => _actualizarDesdePosicion(details.localPosition.dx),
      onPanUpdate: (details) => _actualizarDesdePosicion(details.localPosition.dx),
      child: SizedBox(
        width: _ancho,
        height: _alto + 10,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 5,
              child: Container(
                width: _ancho,
                height: _alto,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_alto / 2),
                  gradient: LinearGradient(colors: [Colors.black, colorPleno]),
                ),
              ),
            ),
            Positioned(
              left: (value * _ancho - 9).clamp(-9, _ancho - 9),
              top: 0,
              child: IgnorePointer(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HSVColor.fromAHSV(1, hue, saturation, value).toColor(),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
