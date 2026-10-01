import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';
import 'color_swatch_picker.dart';
import 'panel_seccion_colapsable.dart';

const List<String> composicionesFuentes = [
  'Inter',
  'Roboto',
  'Montserrat',
  'Merriweather',
  'Oswald',
  'Courier Prime',
  'Noto Sans',
  'Arial',
];

/// Panel de propiedades para un elemento de tipo [TipoElemento.texto]:
/// familia tipográfica, tamaño, negrita/cursiva/subrayado/tachado, color
/// de texto, color de fondo del contenedor (o "sin fondo"), buffer
/// (halo/contorno) y ajustes avanzados (interlineado, tracking,
/// transformación de texto y rotación de la caja).
class PanelPropiedadesTexto extends StatelessWidget {
  const PanelPropiedadesTexto({
    super.key,
    required this.elemento,
    required this.onTextoContenidoChanged,
    required this.onFontFamilyChanged,
    required this.onFontSizeChanged,
    required this.onBoldChanged,
    required this.onItalicChanged,
    required this.onSubrayadoChanged,
    required this.onTachadoChanged,
    required this.onColorTextoChanged,
    required this.onColorFondoChanged,
    required this.onBufferActivoChanged,
    required this.onBufferColorChanged,
    required this.onBufferAnchoChanged,
    required this.onAlineacionChanged,
    required this.onInterlineadoChanged,
    required this.onTrackingChanged,
    required this.onRotacionChanged,
  });

  final ElementoComposicion elemento;
  final ValueChanged<String> onTextoContenidoChanged;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<bool> onBoldChanged;
  final ValueChanged<bool> onItalicChanged;
  final ValueChanged<bool> onSubrayadoChanged;
  final ValueChanged<bool> onTachadoChanged;
  final ValueChanged<String> onColorTextoChanged;
  final ValueChanged<String?> onColorFondoChanged;
  final ValueChanged<bool> onBufferActivoChanged;
  final ValueChanged<String> onBufferColorChanged;
  final ValueChanged<double> onBufferAnchoChanged;
  final ValueChanged<AlineacionTexto> onAlineacionChanged;
  final ValueChanged<double> onInterlineadoChanged;
  final ValueChanged<double> onTrackingChanged;
  final ValueChanged<double> onRotacionChanged;

  @override
  Widget build(BuildContext context) {
    final tamanoActual = elemento.textoFontSize ?? 16;
    final bufferActivo = elemento.textoBufferActivo ?? false;
    final bufferColorActual = elemento.textoBufferColorHex ?? '#FFFFFF';
    final bufferAnchoActual = elemento.textoBufferAncho ?? 3;
    final alineacionActual =
        elemento.textoAlineacion ?? AlineacionTexto.izquierda;
    final interlineadoActual = elemento.textoInterlineado ?? 1.2;
    final trackingActual = elemento.textoTracking ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Texto',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: elemento.textoContenido ?? '',
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          onChanged: onTextoContenidoChanged,
        ),
        const SizedBox(height: 12),
        // Fila 1: tipografía (70%) + tamaño (30%) en un solo bloque.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fuente',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: elemento.textoFontFamily ?? 'Inter',
                    isDense: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    items: composicionesFuentes
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onFontFamilyChanged(v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tamaño',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: ValueKey('tamano_${elemento.id}'),
                    initialValue: tamanoActual.round().toString(),
                    textAlign: TextAlign.end,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      suffixText: 'pt',
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        onFontSizeChanged(parsed);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Segmented control compacto: Negrita / Cursiva / Subrayado / Tachado.
        Align(
          alignment: Alignment.centerLeft,
          child: ToggleButtons(
            borderRadius: BorderRadius.circular(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
            isSelected: [
              elemento.textoBold ?? false,
              elemento.textoItalic ?? false,
              elemento.textoSubrayado ?? false,
              elemento.textoTachado ?? false,
            ],
            onPressed: (index) {
              switch (index) {
                case 0:
                  onBoldChanged(!(elemento.textoBold ?? false));
                case 1:
                  onItalicChanged(!(elemento.textoItalic ?? false));
                case 2:
                  onSubrayadoChanged(!(elemento.textoSubrayado ?? false));
                case 3:
                  onTachadoChanged(!(elemento.textoTachado ?? false));
              }
            },
            children: const [
              Text('B', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('I', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
              Text(
                'U',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  fontSize: 13,
                ),
              ),
              Text(
                'S',
                style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Alineación',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: const [
            (AlineacionTexto.izquierda, Icons.format_align_left),
            (AlineacionTexto.centro, Icons.format_align_center),
            (AlineacionTexto.derecha, Icons.format_align_right),
            (AlineacionTexto.justificado, Icons.format_align_justify),
          ].map((o) {
            final seleccionada = o.$1 == alineacionActual;
            return ChoiceChip(
              label: Icon(o.$2, size: 16),
              labelPadding: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              selected: seleccionada,
              onSelected: (_) => onAlineacionChanged(o.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        ColorSwatchPicker(
          label: 'Color de texto',
          colorHex: elemento.textoColorHex,
          onChanged: (v) {
            if (v != null) onColorTextoChanged(v);
          },
        ),
        const SizedBox(height: 14),
        ColorSwatchPicker(
          label: 'Color de fondo',
          colorHex: elemento.textoColorFondoHex,
          permitirSinColor: true,
          onChanged: onColorFondoChanged,
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),
        const Text(
          'Buffer',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Activar buffer',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            if (bufferActivo) ...[
              ColorSwatchPicker(
                colorHex: bufferColorActual,
                compacto: true,
                onChanged: (v) {
                  if (v != null) onBufferColorChanged(v);
                },
              ),
              const SizedBox(width: 8),
            ],
            Switch(
              value: bufferActivo,
              onChanged: onBufferActivoChanged,
            ),
          ],
        ),
        if (bufferActivo) ...[
          const SizedBox(height: 8),
          const Text(
            'Ancho de buffer',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          _SliderConNumero(
            valor: bufferAnchoActual,
            min: 0,
            max: 10,
            divisiones: 20,
            onChanged: onBufferAnchoChanged,
          ),
        ],
        const SizedBox(height: 8),
        PanelSeccionColapsable(
          titulo: 'Ajustes avanzados de texto',
          icono: Icons.tune,
          inicialmenteExpandido: false,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Interlineado',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 68,
                  child: TextFormField(
                    key: ValueKey('interlineado_${elemento.id}'),
                    initialValue: interlineadoActual.toStringAsFixed(1),
                    textAlign: TextAlign.end,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        onInterlineadoChanged(parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Espaciado entre letras',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 68,
                  child: TextFormField(
                    key: ValueKey('tracking_${elemento.id}'),
                    initialValue: trackingActual.toStringAsFixed(1),
                    textAlign: TextAlign.end,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      suffixText: 'px',
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null) onTrackingChanged(parsed);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Transformar texto',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => onTextoContenidoChanged(
                      (elemento.textoContenido ?? '').toUpperCase(),
                    ),
                    child: const Text('MAYÚS.', style: TextStyle(fontSize: 10)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => onTextoContenidoChanged(
                      (elemento.textoContenido ?? '').toLowerCase(),
                    ),
                    child: const Text('minúsc.', style: TextStyle(fontSize: 10)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => onTextoContenidoChanged(
                      _aTitulo(elemento.textoContenido ?? ''),
                    ),
                    child: const Text('Título', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    'Rotación de la caja',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: TextFormField(
                    key: ValueKey('rotacion_texto_${elemento.id}'),
                    initialValue: elemento.rotacion.round().toString(),
                    textAlign: TextAlign.end,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      suffixText: '°',
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null) {
                        onRotacionChanged(parsed % 360);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _MiniDialRotacion(
                  grados: elemento.rotacion,
                  onChanged: onRotacionChanged,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

String _aTitulo(String texto) {
  return texto
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Slider (con rango [min]-[max]) combinado con un campo numérico
/// editable que refleja el mismo valor -pensado para ajustes que se
/// benefician de un control visual en tiempo real (p.ej. el ancho del
/// buffer) sin perder la precisión de escribir el número directamente.
/// Mantiene su propio [TextEditingController] y solo lo resincroniza
/// desde [valor] cuando el campo no tiene el foco, para no pelearse con
/// lo que el usuario esté tecleando.
class _SliderConNumero extends StatefulWidget {
  const _SliderConNumero({
    required this.valor,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisiones,
  });

  final double valor;
  final double min;
  final double max;
  final int? divisiones;
  final ValueChanged<double> onChanged;

  @override
  State<_SliderConNumero> createState() => _SliderConNumeroState();
}

class _SliderConNumeroState extends State<_SliderConNumero> {
  late final _ctrl =
      TextEditingController(text: widget.valor.toStringAsFixed(1));
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_SliderConNumero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.valor != widget.valor) {
      _ctrl.text = widget.valor.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: widget.valor.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisiones,
            onChanged: widget.onChanged,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: TextFormField(
            controller: _ctrl,
            focusNode: _focus,
            textAlign: TextAlign.end,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) {
                widget.onChanged(parsed.clamp(widget.min, widget.max));
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Minidial circular para girar la caja de texto arrastrando o tocando
/// alrededor del círculo -alternativa visual al campo numérico de grados.
class _MiniDialRotacion extends StatelessWidget {
  const _MiniDialRotacion({required this.grados, required this.onChanged});

  final double grados;
  final ValueChanged<double> onChanged;

  static const _tamano = 32.0;

  void _actualizarDesde(BuildContext context, Offset globalPos) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPos);
    final centro = Offset(box.size.width / 2, box.size.height / 2);
    final delta = local - centro;
    var angulo = math.atan2(delta.dy, delta.dx) * 180 / math.pi + 90;
    if (angulo < 0) angulo += 360;
    onChanged(angulo % 360);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => _actualizarDesde(context, details.globalPosition),
      onTapDown: (details) => _actualizarDesde(context, details.globalPosition),
      child: CustomPaint(
        size: const Size(_tamano, _tamano),
        painter: _DialPainter(grados: grados),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.grados});

  final double grados;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = size.width / 2 - 2;
    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..color = const Color(0xFFD8DBE0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final rad = (grados - 90) * math.pi / 180;
    final punto = centro + Offset(math.cos(rad), math.sin(rad)) * radio;
    canvas.drawLine(
      centro,
      punto,
      Paint()
        ..color = const Color(0xFF1B6CA8)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(centro, 2.5, Paint()..color = const Color(0xFF1B6CA8));
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.grados != grados;
}
