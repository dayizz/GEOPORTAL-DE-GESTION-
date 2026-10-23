import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/estructura/models/proyecto_item.dart';
import 'package:geoportal_predios/features/predios/models/predio.dart';
import 'package:geoportal_predios/features/reportes/utils/balance_calculos.dart';
import 'package:geoportal_predios/features/reportes/presentation/widgets/balance_chart_widgets.dart';

void main() {
  test('marca instalaciones por km sin alterar el porcentaje ni cruzar divisiones', () {
    final proyecto = ProyectoItem(id: 'p', nombre: 'TSNL', descripcion: '', activo: true, createdAt: DateTime(2026), cadenamientos: [
      const Cadenamiento(id: 's', tipoDivision: 'Segmento', pks: [CadenamientoPk(id: '1', numeroId: '1', pkInicio: '10+000', pkFin: '13+000')]),
    ]);
    Predio p(String tipo, double inicio, double fin, {String tramo = 'S1'}) => Predio(id: '$tipo-$inicio', claveCatastral: tipo, tramo: tramo, tipoPropiedad: 'PRIVADA', createdAt: DateTime(2026), estructura: tipo, rangoEstatus: 'Liberado', kmInicio: inicio, kmFin: fin);
    final filas = buildFilasCadenamiento(proyecto, [p('DDV Troncal', 10, 11)], infraestructura: [
      p('Estación', 10.2, 11), p('Edificio auxiliar', 10.5, 10.6),
      p('ZICA', 11, 11), p('ZICA', 12, 13, tramo: 'S2'),
      p('Carretera', 12, 13),
    ]);
    expect(filas.single.columnas.map((c) => c.infraestructuraFerroviaria), [2, 1, 0]);
    expect(filas.single.columnas.map((c) => c.pct), [1, 0, 0]);
  });
  testWidgets('tren debajo del porcentaje solo cuando existen instalaciones', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Row(children: [
      buildCadenamientoCelda(const CadenamientoColumna(10, .5, infraestructuraFerroviaria: 2), 28),
      buildCadenamientoCelda(const CadenamientoColumna(11, 0), 28),
    ]))));
    expect(find.byIcon(Icons.train), findsOneWidget);
    expect(tester.getTopLeft(find.byIcon(Icons.train)).dy, greaterThan(tester.getBottomLeft(find.text('50%')).dy));
    expect(tester.takeException(), isNull);
  });
}
