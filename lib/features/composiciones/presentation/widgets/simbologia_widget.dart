import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../predios/models/predio.dart';
import '../../models/elemento_composicion.dart';

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

String _tituloSimbologia(TipoSimbologia tipo) {
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

/// Leyenda de colores para "Estatus", "Rango de estatus" o "Tipo de
/// propiedad", reutilizando exactamente la misma paleta que Gestión y
/// Mapa (`AppColors`), para que la simbología impresa coincida con lo
/// que se ve en el resto de la app.
class SimbologiaWidget extends StatelessWidget {
  const SimbologiaWidget({super.key, required this.tipo});

  final TipoSimbologia tipo;

  @override
  Widget build(BuildContext context) {
    final entradas = _entradasDe(tipo);
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border.all(color: Colors.black26, width: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _tituloSimbologia(tipo),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          for (final e in entradas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: e.color,
                      border: e.borde != null ? Border.all(color: e.borde!, width: 1.2) : null,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      e.label,
                      style: const TextStyle(fontSize: 8.5, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
