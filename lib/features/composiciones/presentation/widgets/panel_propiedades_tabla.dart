import '../../../../core/constants/app_colors.dart';
import 'dart:math' as math;
import 'panel_seccion_colapsable.dart';
import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';
import 'color_swatch_picker.dart';
import 'panel_propiedades_texto.dart' show composicionesFuentes;
import 'tabla_widget.dart';
import '../../utils/tabla_ops.dart';

const _opcionesEstiloLinea = [
  (EstiloLinea.continua, 'Continua'),
  (EstiloLinea.segmentada, 'Segmentada'),
  (EstiloLinea.punteada, 'Punteada'),
  (EstiloLinea.lineaPunto, 'Línea-punto'),
];

const _opcionesAlineacion = [
  (AlineacionTexto.izquierda, Icons.format_align_left, 'Izquierda'),
  (AlineacionTexto.centro, Icons.format_align_center, 'Centro'),
  (AlineacionTexto.derecha, Icons.format_align_right, 'Derecha'),
];

const _titulo = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

/// Panel de propiedades para [TipoElemento.tabla]. El contenido se escribe
/// directo en las celdas del lienzo; aquí se ajustan filas/columnas, los
/// bordes de la tabla y el estilo (relleno y texto) de las celdas
/// [seleccion]adas o en edición.
class PanelPropiedadesTabla extends StatelessWidget {
  const PanelPropiedadesTabla({
    super.key,
    required this.elemento,
    required this.seleccion,
    required this.onChanged,
    required this.onSeleccionChanged,
  });
  final ElementoComposicion elemento;
  final Set<CeldaTabla> seleccion;
  final ValueChanged<ElementoComposicion Function(ElementoComposicion)> onChanged;
  // Al insertar/eliminar filas o columnas la selección se reubica.
  final ValueChanged<Set<CeldaTabla>> onSeleccionChanged;

  Set<int> get _filasSel => {for (final c in seleccion) c.$1};
  Set<int> get _columnasSel => {for (final c in seleccion) c.$2};

  void _insertarFila({required bool abajo}) {
    final i = abajo ? _filasSel.reduce(math.max) + 1 : _filasSel.reduce(math.min);
    onChanged((e) => insertarFilaTabla(e, i));
    onSeleccionChanged({for (final (f, c) in seleccion) (f >= i ? f + 1 : f, c)});
  }

  void _insertarColumna({required bool derecha}) {
    final j = derecha ? _columnasSel.reduce(math.max) + 1 : _columnasSel.reduce(math.min);
    onChanged((e) => insertarColumnaTabla(e, j));
    onSeleccionChanged({for (final (f, c) in seleccion) (f, c >= j ? c + 1 : c)});
  }

  void _eliminarFilas() {
    final filas = _filasSel;
    onChanged((e) => eliminarFilasTabla(e, filas));
    onSeleccionChanged({});
  }

  void _eliminarColumnas() {
    final columnas = _columnasSel;
    onChanged((e) => eliminarColumnasTabla(e, columnas));
    onSeleccionChanged({});
  }

  /// Aplica [cambio] (solo los campos no nulos) a cada celda seleccionada.
  void _aplicarEstilo(EstiloCeldaTabla cambio) => onChanged((e) {
    final estilos = {...e.tablaEstilosCelda};
    for (final (f, c) in seleccion) {
      final clave = EstiloCeldaTabla.claveCelda(f, c);
      estilos[clave] = cambio.sobre(estilos[clave] ?? const EstiloCeldaTabla());
    }
    return e.copyWith(tablaEstilosCelda: estilos);
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seccionFilasColumnas(),
        if (seleccion.isNotEmpty) _seccionTamanoCelda(),
        _seccionBordes(),
        ..._seccionesCeldas(),
      ],
    );
  }

  Widget _seccionFilasColumnas() {
    final filas = elemento.tablaCeldas.length;
    final columnas = columnasTabla(elemento.tablaCeldas);
    final haySel = seleccion.isNotEmpty;
    return PanelSeccionColapsable(
      titulo: 'Filas y columnas',
      icono: Icons.table_chart_outlined,
      children: [
        Text(
          'Doble clic en una celda para escribir. Clic para seleccionarla, '
          'Shift+clic para un rango. '
          'Arrastra las líneas entre columnas o filas para cambiar su tamaño.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (!haySel) ...[
          const SizedBox(height: 6),
          Text(
            'Selecciona una celda para insertar o eliminar filas y columnas junto a ella.',
            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ],
        const SizedBox(height: 6),
        const Text('Insertar fila', style: _titulo),
        Row(children: [
          Expanded(child: _botonAccion(Icons.vertical_align_top, 'Arriba',
              haySel ? () => _insertarFila(abajo: false) : null)),
          Expanded(child: _botonAccion(Icons.vertical_align_bottom, 'Abajo',
              haySel ? () => _insertarFila(abajo: true) : null)),
        ]),
        const SizedBox(height: 4),
        const Text('Insertar columna', style: _titulo),
        Row(children: [
          Expanded(child: _botonAccion(Icons.keyboard_tab_rounded, 'Izquierda',
              haySel ? () => _insertarColumna(derecha: false) : null, espejo: true)),
          Expanded(child: _botonAccion(Icons.keyboard_tab_rounded, 'Derecha',
              haySel ? () => _insertarColumna(derecha: true) : null)),
        ]),
        const SizedBox(height: 4),
        const Text('Eliminar', style: _titulo),
        Row(children: [
          Expanded(child: _botonAccion(Icons.delete_sweep_outlined,
              _filasSel.length > 1 ? 'Filas' : 'Fila',
              haySel && _filasSel.length < filas ? _eliminarFilas : null)),
          Expanded(child: _botonAccion(Icons.delete_sweep_outlined,
              _columnasSel.length > 1 ? 'Columnas' : 'Columna',
              haySel && _columnasSel.length < columnas ? _eliminarColumnas : null)),
        ]),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _botonAccion(IconData icono, String texto, VoidCallback? onPressed, {bool espejo = false}) {
    Widget icon = Icon(icono, size: 18);
    if (espejo) icon = Transform.flip(flipX: true, child: icon);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(texto, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
    );
  }

  /// Ancho de las columnas y alto de las filas de las celdas
  /// seleccionadas, en mm. Cambiarlos hace crecer o encoger la tabla.
  Widget _seccionTamanoCelda() {
    final anchos = anchosColumnaMm(elemento);
    final altos = altosFilaMm(elemento);
    final columnas = _columnasSel.where((c) => c < anchos.length).toList()..sort();
    final filas = _filasSel.where((f) => f < altos.length).toList()..sort();
    if (columnas.isEmpty || filas.isEmpty) return const SizedBox.shrink();
    final ancho = anchos[columnas.first];
    final alto = altos[filas.first];
    final claveSel = seleccion.map((c) => '${c.$1}_${c.$2}').join(',');
    return PanelSeccionColapsable(
      titulo: 'Tamaño de celda',
      icono: Icons.photo_size_select_small,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('tabla_ancho_${elemento.id}_${claveSel}_${ancho.toStringAsFixed(1)}'),
                initialValue: ancho.toStringAsFixed(1),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Ancho de columna', suffixText: 'mm', isDense: true),
                onFieldSubmitted: (v) {
                  final mm = double.tryParse(v.replaceAll(',', '.'));
                  if (mm == null || mm <= 0) return;
                  onChanged((e) {
                    for (final c in columnas) {
                      e = fijarAnchoColumna(e, c, mm);
                    }
                    return e;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                key: ValueKey('tabla_alto_${elemento.id}_${claveSel}_${alto.toStringAsFixed(1)}'),
                initialValue: alto.toStringAsFixed(1),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Alto de fila', suffixText: 'mm', isDense: true),
                onFieldSubmitted: (v) {
                  final mm = double.tryParse(v.replaceAll(',', '.'));
                  if (mm == null || mm <= 0) return;
                  onChanged((e) {
                    for (final f in filas) {
                      e = fijarAltoFila(e, f, mm);
                    }
                    return e;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Escribe la medida y presiona Enter.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        _botonAccion(Icons.view_column_outlined, 'Igualar ancho de todas las columnas',
            () => onChanged((e) => e.copyWith(tablaAnchosColumna: const []))),
        _botonAccion(Icons.table_rows_outlined, 'Igualar alto de todas las filas',
            () => onChanged((e) => e.copyWith(tablaAltosFila: const []))),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _seccionBordes() {
    final grosor = elemento.tablaBordeGrosor ?? 1;
    return PanelSeccionColapsable(
      titulo: 'Bordes',
      icono: Icons.border_all,
      children: [
        DropdownButtonFormField<EstiloLinea>(
          key: ValueKey('tabla_borde_${elemento.id}_${elemento.tablaBordeEstilo?.name}'),
          initialValue: elemento.tablaBordeEstilo ?? EstiloLinea.continua,
          decoration: const InputDecoration(labelText: 'Tipo de línea', isDense: true),
          items: [
            for (final (estilo, nombre) in _opcionesEstiloLinea)
              DropdownMenuItem(value: estilo, child: Text(nombre, style: const TextStyle(fontSize: 12))),
          ],
          onChanged: (v) {
            if (v != null) onChanged((e) => e.copyWith(tablaBordeEstilo: v));
          },
        ),
        const SizedBox(height: 8),
        Text('Grosor: ${grosor.toStringAsFixed(1)}', style: _titulo),
        Slider(
          value: grosor.clamp(0.5, 6),
          min: 0.5,
          max: 6,
          divisions: 11,
          onChanged: (v) => onChanged((e) => e.copyWith(tablaBordeGrosor: v)),
        ),
        ColorSwatchPicker(
          label: 'Color de línea',
          colorHex: elemento.tablaBordeColorHex ?? '#757575',
          onChanged: (v) {
            if (v != null) onChanged((e) => e.copyWith(tablaBordeColorHex: v));
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _seccionesCeldas() {
    if (seleccion.isEmpty) {
      return [
        PanelSeccionColapsable(
          titulo: 'Celdas',
          icono: Icons.grid_on,
          children: [
            Text(
              'Selecciona una o varias celdas en la tabla para cambiar su '
              'relleno y estilo de texto.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            SizedBox(height: 8),
          ],
        ),
      ];
    }
    // Los controles muestran el estilo de la primera celda seleccionada.
    final (f0, c0) = (seleccion.toList()..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2)).first;
    final actual = EstiloCeldaTabla.efectivo(elemento.tablaEstilosCelda, f0, c0);
    final claveSel = seleccion.map((c) => '${c.$1}_${c.$2}').join(',');
    final n = seleccion.length;
    return [
      PanelSeccionColapsable(
        titulo: 'Relleno de celda',
        icono: Icons.format_color_fill,
        children: [
          Text(n == 1 ? '1 celda seleccionada' : '$n celdas seleccionadas',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ColorSwatchPicker(
            label: 'Color de relleno',
            colorHex: actual.rellenoHex,
            onChanged: (v) {
              if (v != null) _aplicarEstilo(EstiloCeldaTabla(rellenoHex: v));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
      PanelSeccionColapsable(
        titulo: 'Estilo de texto',
        icono: Icons.text_fields,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('tabla_fuente_${elemento.id}_${claveSel}_${actual.fuente}'),
            initialValue: actual.fuente,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tipo de letra', isDense: true),
            items: {...composicionesFuentes, actual.fuente!}
                .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (v) {
              if (v != null) _aplicarEstilo(EstiloCeldaTabla(fuente: v));
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('tabla_tamano_${elemento.id}_$claveSel'),
            initialValue: _formatoNumero(actual.tamano!),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tamaño', suffixText: 'px', isDense: true),
            onChanged: (v) {
              final t = double.tryParse(v.replaceAll(',', '.'));
              if (t != null && t > 0) _aplicarEstilo(EstiloCeldaTabla(tamano: t.clamp(1, 96)));
            },
          ),
          const SizedBox(height: 12),
          const Text('Estilo', style: _titulo),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _botonEstilo(Icons.format_bold, 'Negrita', actual.negrita!,
                  () => _aplicarEstilo(EstiloCeldaTabla(negrita: !actual.negrita!))),
              _botonEstilo(Icons.format_italic, 'Cursiva', actual.cursiva!,
                  () => _aplicarEstilo(EstiloCeldaTabla(cursiva: !actual.cursiva!))),
              _botonEstilo(Icons.format_underlined, 'Subrayado', actual.subrayado!,
                  () => _aplicarEstilo(EstiloCeldaTabla(subrayado: !actual.subrayado!))),
              const SizedBox(width: 8),
              for (final (alineacion, icono, nombre) in _opcionesAlineacion)
                _botonEstilo(icono, nombre, actual.alineacion == alineacion,
                    () => _aplicarEstilo(EstiloCeldaTabla(alineacion: alineacion))),
            ],
          ),
          const SizedBox(height: 12),
          ColorSwatchPicker(
            label: 'Color de texto',
            colorHex: actual.colorHex,
            onChanged: (v) {
              if (v != null) _aplicarEstilo(EstiloCeldaTabla(colorHex: v));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ];
  }

  Widget _botonEstilo(IconData icono, String nombre, bool activo, VoidCallback onTap) => Tooltip(
    message: nombre,
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: activo ? Colors.blueAccent.withValues(alpha: 0.15) : null,
          border: Border.all(color: activo ? Colors.blueAccent : AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icono, size: 18, color: activo ? Colors.blueAccent : AppColors.textPrimary),
      ),
    ),
  );
}

String _formatoNumero(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
