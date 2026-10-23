import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../utils/balance_calculos.dart';

class AvanceGeneralWidget extends StatelessWidget {
  const AvanceGeneralWidget({super.key, required this.avance, this.grupo = GrupoInfraestructuraBalance.predios});
  final AvanceGeneralBalance avance;
  final GrupoInfraestructuraBalance grupo;

  @override
  Widget build(BuildContext context) {
    final enteros = NumberFormat('#,##0', 'es_MX');
    final medidas = NumberFormat('#,##0.###', 'es_MX');
    Widget tarjeta(String label, String value, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.26)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, height: 1.2)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: color)),
          ),
        ],
      ),
    );
    Widget fila(List<Widget> tarjetas) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tarjetas.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: tarjetas[i]),
        ],
      ],
    );
    if (grupo == GrupoInfraestructuraBalance.estacionesEdificios ||
        grupo == GrupoInfraestructuraBalance.cruces) {
      final estaciones = grupo == GrupoInfraestructuraBalance.estacionesEdificios;
      final registros = estaciones ? avance.estaciones : avance.cruces;
      final liberados = registros.where(predioEstaLiberado).length;
      final medida = registros.where(predioEstaLiberado).fold<double>(
        0, (sum, p) => sum + medidaPredioBalance(p, usaM2: estaciones),
      );
      final categoria = estaciones ? 'Estaciones y Edif. Auxiliares' : 'Cruces/Transversales';
      return LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(880, constraints.maxWidth),
            child: IntrinsicHeight(child: fila([
              tarjeta('Total de registros clasificados en $categoria', enteros.format(registros.length), AppColors.primary),
              tarjeta('Total no liberados en $categoria', enteros.format(registros.length - liberados), AppColors.danger),
              tarjeta('Total liberados en $categoria', enteros.format(liberados), AppColors.secondary),
              tarjeta(estaciones ? 'm² efectivos liberados en $categoria' : 'Km efectivos liberados en $categoria',
                '${medidas.format(medida)} ${estaciones ? 'm²' : 'km'}', AppColors.secondary),
            ])),
          ),
        );
      });
    }
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(1100, constraints.maxWidth),
          child: IntrinsicHeight(
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tarjeta('Total de registros clasificados', enteros.format(avance.total), AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Column(children: [
                  IntrinsicHeight(child: fila([
                    tarjeta('Total de predios en troncal', enteros.format(avance.troncal.length), AppColors.primary),
                    tarjeta('Total no liberados en troncal', enteros.format(avance.noLiberadosTroncal), AppColors.danger),
                    tarjeta('Total liberados en troncal', enteros.format(avance.liberadosTroncal), AppColors.secondary),
                    tarjeta('Km efectivos liberados en troncal', '${medidas.format(avance.kmLiberados)} km', AppColors.secondary),
                  ])),
                  const SizedBox(height: 8),
                  IntrinsicHeight(child: fila([
                    tarjeta('Total de Estaciones y Edif. Auxiliares', enteros.format(avance.estaciones.length), AppColors.primary),
                    tarjeta('Total no liberados en Estaciones y Edif. Auxiliares', enteros.format(avance.noLiberadosEstaciones), AppColors.danger),
                    tarjeta('Total liberados en Estaciones y Edif. Auxiliares', enteros.format(avance.liberadosEstaciones), AppColors.secondary),
                    tarjeta('m² efectivos liberados en Estaciones y Edif. Auxiliares', '${medidas.format(avance.m2Liberados)} m²', AppColors.secondary),
                  ])),
                ]),
              ),
            ],
            ),
          ),
        ),
      );
    });
  }
}
