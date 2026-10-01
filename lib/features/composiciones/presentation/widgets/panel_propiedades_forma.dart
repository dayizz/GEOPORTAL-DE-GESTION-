import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/elemento_composicion.dart';
import 'color_swatch_picker.dart';
import 'shape_painter.dart';

const _opcionesEstiloLinea = [
  (EstiloLinea.continua, 'Continua'),
  (EstiloLinea.segmentada, 'Segmentada'),
  (EstiloLinea.punteada, 'Punteada'),
  (EstiloLinea.lineaPunto, 'Línea-punto'),
];

const _opcionesPuntaLinea = [
  (TipoPuntaLinea.ninguna, 'Ninguna'),
  (TipoPuntaLinea.flecha, 'Flecha'),
  (TipoPuntaLinea.punto, 'Punto'),
];

/// Panel de propiedades para un elemento de tipo [TipoElemento.forma]:
/// color de trazo, grosor, estilo de línea, color de relleno (o "sin
/// relleno") y -solo para [TipoFigura.linea]- la punta decorativa en sus
/// extremos.
class PanelPropiedadesForma extends StatelessWidget {
  const PanelPropiedadesForma({
    super.key,
    required this.elemento,
    required this.onColorTrazoChanged,
    required this.onGrosorChanged,
    required this.onEstiloLineaChanged,
    required this.onEspaciadoLineaChanged,
    required this.onColorRellenoChanged,
    required this.onPuntaTipoChanged,
    required this.onPuntaTamanoChanged,
    required this.onPuntaIzquierdaChanged,
    required this.onPuntaDerechaChanged,
  });

  final ElementoComposicion elemento;
  final ValueChanged<String> onColorTrazoChanged;
  final ValueChanged<double> onGrosorChanged;
  final ValueChanged<EstiloLinea> onEstiloLineaChanged;
  final ValueChanged<double> onEspaciadoLineaChanged;
  final ValueChanged<String?> onColorRellenoChanged;
  final ValueChanged<TipoPuntaLinea> onPuntaTipoChanged;
  final ValueChanged<double> onPuntaTamanoChanged;
  final ValueChanged<bool> onPuntaIzquierdaChanged;
  final ValueChanged<bool> onPuntaDerechaChanged;

  @override
  Widget build(BuildContext context) {
    final estiloLineaActual = elemento.estiloLinea ?? EstiloLinea.continua;
    final espaciadoLineaActual = elemento.estiloLineaEspaciado ?? 1.0;
    final puntaTipoActual = elemento.lineaPuntaTipo ?? TipoPuntaLinea.ninguna;
    final puntaTamanoActual = elemento.lineaPuntaTamano ?? 10;
    final puntaIzquierdaActual = elemento.lineaPuntaIzquierda ?? false;
    final puntaDerechaActual = elemento.lineaPuntaDerecha ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ColorSwatchPicker(
          label: 'Color de trazo',
          colorHex: elemento.colorTrazoHex,
          onChanged: (v) {
            if (v != null) onColorTrazoChanged(v);
          },
        ),
        const SizedBox(height: 14),
        Text('Grosor de trazo: ${(elemento.grosorTrazo ?? 2).toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        Slider(
          value: (elemento.grosorTrazo ?? 2).clamp(0.5, 12),
          min: 0.5,
          max: 12,
          onChanged: onGrosorChanged,
        ),
        const SizedBox(height: 8),
        const Text(
          'Tipo de línea',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _opcionesEstiloLinea.map((o) {
            final seleccionado = o.$1 == estiloLineaActual;
            return Tooltip(
              message: o.$2,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onEstiloLineaChanged(o.$1),
                child: Container(
                  width: 54,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: seleccionado ? AppColors.primary : Colors.black26,
                      width: seleccionado ? 1.6 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    color: seleccionado
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : null,
                  ),
                  child: CustomPaint(
                    size: const Size(36, 12),
                    painter: _EstiloLineaPreviewPainter(estilo: o.$1),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (estiloLineaActual != EstiloLinea.continua) ...[
          const SizedBox(height: 10),
          Text(
            'Espaciado: ${espaciadoLineaActual.toStringAsFixed(1)}x',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: espaciadoLineaActual.clamp(0.4, 3.0),
            min: 0.4,
            max: 3.0,
            divisions: 26,
            onChanged: onEspaciadoLineaChanged,
          ),
        ],
        if (elemento.figuraTipo == TipoFigura.linea) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Text(
            'Punta de línea',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _opcionesPuntaLinea.map((o) {
              final seleccionado = o.$1 == puntaTipoActual;
              return Tooltip(
                message: o.$2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onPuntaTipoChanged(o.$1),
                  child: Container(
                    width: 54,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: seleccionado ? AppColors.primary : Colors.black26,
                        width: seleccionado ? 1.6 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      color: seleccionado
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : null,
                    ),
                    child: CustomPaint(
                      size: const Size(32, 16),
                      painter: _PuntaLineaPreviewPainter(tipo: o.$1),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (puntaTipoActual != TipoPuntaLinea.ninguna) ...[
            const SizedBox(height: 12),
            Text(
              'Tamaño de la punta: ${puntaTamanoActual.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Slider(
              value: puntaTamanoActual.clamp(4, 30),
              min: 4,
              max: 30,
              onChanged: onPuntaTamanoChanged,
            ),
            const SizedBox(height: 8),
            const Text(
              'Posición',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text('Izquierda', style: TextStyle(fontSize: 11)),
                    selected: puntaIzquierdaActual,
                    onSelected: onPuntaIzquierdaChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('Derecha', style: TextStyle(fontSize: 11)),
                    selected: puntaDerechaActual,
                    onSelected: onPuntaDerechaChanged,
                  ),
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 14),
        ColorSwatchPicker(
          label: 'Color de relleno',
          colorHex: elemento.colorRellenoHex,
          permitirSinColor: true,
          onChanged: onColorRellenoChanged,
        ),
      ],
    );
  }
}

/// Miniatura de una línea horizontal en el [EstiloLinea] dado, usada como
/// vista previa dentro de cada celda del selector -reusa la misma lógica
/// de segmentado que [ShapePainter] para que la previsualización coincida
/// exactamente con el resultado sobre la figura.
class _EstiloLineaPreviewPainter extends CustomPainter {
  const _EstiloLineaPreviewPainter({required this.estilo});

  final EstiloLinea estilo;

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 2.0;
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = grosor
      ..style = PaintingStyle.stroke
      ..strokeCap = estilo == EstiloLinea.continua ? StrokeCap.butt : StrokeCap.round;
    final y = size.height / 2;
    final linea = Path()
      ..moveTo(0, y)
      ..lineTo(size.width, y);
    canvas.drawPath(estiloLineaDe(linea, estilo, grosor), paint);
  }

  @override
  bool shouldRepaint(covariant _EstiloLineaPreviewPainter oldDelegate) =>
      oldDelegate.estilo != estilo;
}

/// Miniatura de una línea horizontal con la punta [tipo] en su extremo
/// derecho, usada como vista previa dentro de cada celda del selector de
/// puntas -reusa [dibujarPuntaLinea], la misma función que usa
/// [ShapePainter] al renderizar la figura real.
class _PuntaLineaPreviewPainter extends CustomPainter {
  const _PuntaLineaPreviewPainter({required this.tipo});

  final TipoPuntaLinea tipo;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()..color = AppColors.textPrimary;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width - 6, y),
      paint..strokeWidth = 2,
    );
    dibujarPuntaLinea(
      canvas,
      Paint()..color = AppColors.textPrimary,
      Offset(size.width - 2, y),
      const Offset(1, 0),
      tipo,
      7,
    );
  }

  @override
  bool shouldRepaint(covariant _PuntaLineaPreviewPainter oldDelegate) =>
      oldDelegate.tipo != tipo;
}
