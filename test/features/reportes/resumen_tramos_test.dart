import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/reportes/utils/resumen_tramos.dart';
import 'package:geoportal_predios/features/estructura/models/proyecto_item.dart';
import 'package:geoportal_predios/features/predios/models/predio.dart';

void main() {
  test('avance usa km liberados sobre longitud y distingue IDs alfanuméricos', () {
    final proyecto = ProyectoItem(id: 'p', nombre: 'P', descripcion: '', activo: true,
      createdAt: DateTime(2026), cadenamientos: [
        Cadenamiento(id: 'c', tipoDivision: 'Tramo', pks: [
          CadenamientoPk(id: '1', numeroId: '1', pkInicio: '10+000', pkFin: '20+000'),
          CadenamientoPk(id: '2', numeroId: '1A', pkInicio: '20+000', pkFin: '25+000'),
        ]),
      ]);
    Predio p(String tramo, String estatus, double km) => Predio(id: '$tramo$estatus',
      claveCatastral: 'x', tramo: tramo, rangoEstatus: estatus, kmEfectivos: km,
      tipoPropiedad: 'PRIVADA', createdAt: DateTime(2026));
    final filas = resumenTramosBalance(proyecto, [p('T1', 'Liberado', 2),
      p('1', 'No liberado', 8), p('1A', 'Liberado', 1)]);
    expect(filas.length, 2);
    expect(claveTramoBalance('13'), 'S13');
    expect(claveTramoBalance('15a1'), 'S15A1');
    expect(claveTramoBalance('s15a1'), 'S15A1');
    expect(filas.first.predios.length, 2);
    expect(filas.first.liberados, 1);
    expect(filas.first.porcentaje, 20); // 2 / 10 km, no 1 / 2 predios.
    expect(filas.last.kmLiberados, 1);
    expect(resumenTramosBalance(null, [p('T2', 'Liberado', 1)]).single.porcentaje, isNull);
    expect(resumenTramosBalance(proyecto, [], segmento: 'T1A').single.codigo, 'T1A');
  });
}
