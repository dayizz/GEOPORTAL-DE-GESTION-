import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/core/constants/app_colors.dart';
import 'package:geoportal_predios/core/utils/import_normalization.dart' as norm;
import 'package:geoportal_predios/features/predios/models/predio.dart';

Predio predio(String? estructura, String estatus) => Predio(
  id: 'p', claveCatastral: 'p', tramo: 'S1', tipoPropiedad: 'PRIVADA',
  estructura: estructura, rangoEstatus: estatus, createdAt: DateTime(2026),
);

void main() {
  test('sin infraestructura queda en investigación al leer y serializar', () {
    for (final tipo in [null, '', ' ', '-', 'SIN TIPO', 'sin tipo']) {
      final p = predio(tipo, 'Liberado');
      expect(p.rangoEstatus, 'Investigación');
      expect(p.toMap()['rango_estatus'], 'Investigación');
    }
  });
  test('seleccionar SIN TIPO actualiza el estatus sin afectar clasificaciones reales', () {
    final p = predio('Estacion', 'No liberado');
    expect(p.rangoEstatus, 'No liberado');
    expect(p.copyWith(estructura: 'SIN TIPO').rangoEstatus, 'Investigación');
    expect(predio('Sin afectación', 'Liberado').rangoEstatus, 'Liberado');
    expect(predio('DDV Troncal', 'Investigacion').rangoEstatus, 'Investigación');
  });
  test('payload de importación sin tipo se guarda como investigación', () {
    final data = <String, dynamic>{'rango_estatus': 'No liberado'};
    norm.aplicarEstatusInfraestructura(data);
    expect(data['estructura'], 'SIN TIPO');
    expect(data['rango_estatus'], 'Investigación');
    final completo = <String, dynamic>{'estructura': 'Viaducto', 'rango_estatus': 'Liberado'};
    norm.aplicarEstatusInfraestructura(completo);
    expect(completo['rango_estatus'], 'Liberado');
    expect(norm.estructuraOpciones, contains('SIN TIPO'));
  });
  test('no liberado es rojo y solo investigación es gris en colores por estatus', () {
    expect(AppColors.rangoEstatusColor('NO LIBERADO'), AppColors.rangoNoLiberado);
    expect(AppColors.rangoEstatusColor('Investigacion'), AppColors.rangoInvestigacion);
    expect(AppColors.estatusPredioColor('No liberado'), isNot(AppColors.rangoInvestigacion));
    expect(AppColors.estatusPredioColor('Investigación'), AppColors.rangoInvestigacion);
    expect(AppColors.estatusPredioColor(null), isNot(AppColors.rangoInvestigacion));
  });
}
