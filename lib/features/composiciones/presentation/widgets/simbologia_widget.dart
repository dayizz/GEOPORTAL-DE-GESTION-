import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../predios/models/predio.dart';
import '../../models/elemento_composicion.dart';
import '../../utils/color_hex.dart';

class _EntradaSimbologia {
  const _EntradaSimbologia(this.label, this.color, [this.borde]);
  final String label;
  final Color color;
  final Color? borde;
}

/// Catálogos de "Tipo de propiedad" reutilizados tal cual de
/// `AppColors.tipoPropiedadColor` (mismas categorías que Gestión/Mapa).
const List<String> _tiposPropiedad = [
  'PRIVADA',
  'SOCIAL',
  'DOMINIO PLENO',
  'GUBERNAMENTAL',
  'MUNICIPAL',
  'ESTATAL',
  'FEDERAL',
];

/// Título automático ("actual") de la simbología según su clasificación.
String tituloSimbologia(TipoSimbologia tipo) {
  switch (tipo) {
    case TipoSimbologia.estatus:
      return 'Estatus';
    case TipoSimbologia.rangoEstatus:
      return 'Rango de estatus';
    case TipoSimbologia.tipoPropiedad:
      return 'Tipo de propiedad';
  }
}

List<_EntradaSimbologia> _entradasDe(TipoSimbologia tipo) {
  switch (tipo) {
    case TipoSimbologia.estatus:
      return [
        _EntradaSimbologia('Liberado', AppColors.secondary),
        _EntradaSimbologia('No liberado', AppColors.danger),
      ];
    case TipoSimbologia.rangoEstatus:
      return Predio.rangoEstatusOpciones
          .map((r) => _EntradaSimbologia(r, AppColors.rangoEstatusColor(r), AppColors.rangoEstatusBorderColor(r)))
          .toList();
    case TipoSimbologia.tipoPropiedad:
      return _tiposPropiedad
          .map((t) => _EntradaSimbologia(_tituloCase(t), AppColors.tipoPropiedadColor(t)))
          .toList();
  }
}

String _tituloCase(String texto) {
  final palabras = texto.toLowerCase().split(' ');
  return palabras.map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}').join(' ');
}

TextStyle _estiloTexto(EstiloTextoSimbologia e) {
  final base = TextStyle(
    fontSize: e.tamano,
    fontWeight: FontWeight.values[((e.grosor ~/ 100) - 1).clamp(0, 8)],
    fontStyle: e.cursiva ? FontStyle.italic : FontStyle.normal,
    color: colorFromHex(e.colorHex) ?? Colors.black87,
  );
  // 'Arial' no está en Google Fonts: se usa la fuente nativa del sistema.
  if (e.fuente == 'Arial' || !GoogleFonts.asMap().containsKey(e.fuente)) {
    return base.copyWith(fontFamily: e.fuente);
  }
  return GoogleFonts.getFont(e.fuente, textStyle: base);
}

/// Leyenda de colores para "Estatus", "Rango de estatus" o "Tipo de
/// propiedad", reutilizando exactamente la misma paleta que Gestión y
/// Mapa (`AppColors`), para que la simbología impresa coincida con lo
/// que se ve en el resto de la app. El título, la tipografía, el tamaño
/// de símbolo, la separación, las columnas y el fondo salen de [estilo].
class SimbologiaWidget extends StatelessWidget {
  const SimbologiaWidget({
    super.key,
    required this.tipo,
    this.estilo = const EstiloSimbologia(),
  });

  final TipoSimbologia tipo;
  final EstiloSimbologia estilo;

  @override
  Widget build(BuildContext context) {
    final entradas = _entradasDe(tipo);
    final columnas = estilo.columnas.clamp(1, 4);
    // Reparto equitativo: cada columna recibe ceil(n / columnas) entradas,
    // llenando de arriba a abajo y de izquierda a derecha.
    final porColumna = (entradas.length / columnas).ceil();
    final grupos = [
      for (var c = 0; c < columnas; c++)
        entradas.skip(c * porColumna).take(porColumna).toList(),
    ];
    final titulo = estilo.tituloPersonalizado
        ? estilo.tituloTexto
        : tituloSimbologia(tipo);
    final estiloEtiqueta = _estiloTexto(estilo.estiloEtiquetas);
    final fondo = colorFromHex(estilo.fondoColorHex) ?? Colors.white;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: estilo.fondoActivo
          ? BoxDecoration(
              color: aplicarOpacidad(fondo, estilo.fondoOpacidad),
              border: Border.all(color: Colors.black26, width: 0.6),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      // Recorta sin franjas de desbordamiento si la caja queda chica.
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (titulo.trim().isNotEmpty) ...[
                Text(titulo, style: _estiloTexto(estilo.estiloTitulo)),
                const SizedBox(height: 4),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < grupos.length; c++) ...[
                    if (c > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final e in grupos[c])
                            _fila(e, estiloEtiqueta),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fila(_EntradaSimbologia e, TextStyle estiloEtiqueta) {
    final tam = estilo.tamanoSimbolo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Container(
            width: tam,
            height: tam,
            decoration: BoxDecoration(
              color: e.color,
              border: e.borde != null ? Border.all(color: e.borde!, width: 1.2) : null,
            ),
          ),
          SizedBox(width: estilo.separacion),
          Flexible(
            child: Text(
              e.label,
              style: estiloEtiqueta,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
