import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/predios/models/predio.dart';
import 'package:geoportal_predios/features/reportes/utils/balance_calculos.dart';
import 'package:geoportal_predios/features/reportes/presentation/widgets/avance_general_widget.dart';

Predio registro(String tipo, {String tramo = 'S1', bool liberado = true}) => Predio(
  id: '$tipo-$tramo', claveCatastral: tipo, tramo: tramo,
  tipoPropiedad: 'PRIVADA', createdAt: DateTime(2026),
  estructura: tipo, rangoEstatus: liberado ? 'Liberado' : 'No liberado',
  kmEfectivos: 2, superficie: 100,
);

void main() {
  final registros = [
    registro('DDV'), registro('Carretera', liberado: false), registro('Viaducto'),
    registro('Estación'), registro('Edificio auxiliar', liberado: false), registro('ZICA', tramo: 'S2'),
    registro('Cruce/Transversal'), registro('SIN TIPO'), registro('Sin afectación'),
  ];
  test('total suma ambas categorías y separa km y superficie liberados', () {
    final avance = AvanceGeneralBalance(registros);
    expect(avance.total, 6);
    expect(avance.troncal.length, 3);
    expect(avance.estaciones.length, 3);
    expect(avance.liberadosTroncal, 2);
    expect(avance.noLiberadosTroncal, 1);
    expect(avance.liberadosEstaciones, 2);
    expect(avance.noLiberadosEstaciones, 1);
    expect(avance.kmLiberados, 4);
    expect(avance.m2Liberados, 200);
  });
  test('respeta los registros de la división seleccionada y el conjunto vacío', () {
    final avance = AvanceGeneralBalance(registros.where((p) => p.tramo == 'S2'));
    expect(avance.total, 1);
    expect(avance.troncal.length, 0);
    expect(avance.m2Liberados, 100);
    final vacio = AvanceGeneralBalance([]);
    expect(vacio.total, 0);
    expect(vacio.kmLiberados, 0);
    expect(vacio.m2Liberados, 0);
  });
  testWidgets('dos filas con total a toda altura, sin desbordamiento en móvil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AvanceGeneralWidget(avance: AvanceGeneralBalance(registros)))));
    expect(tester.takeException(), isNull);
    expect(find.text('Total de registros clasificados'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Total de predios en troncal')).dy,
      lessThan(tester.getTopLeft(find.text('Total de Estaciones y Edif. Auxiliares')).dy));
  });
  for (final grupo in [GrupoInfraestructuraBalance.estacionesEdificios, GrupoInfraestructuraBalance.cruces]) {
    testWidgets('avance exclusivo de $grupo', (tester) async {
      final estaciones = grupo == GrupoInfraestructuraBalance.estacionesEdificios;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AvanceGeneralWidget(
        avance: AvanceGeneralBalance(registros), grupo: grupo,
      ))));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('troncal'), findsNothing);
      expect(find.text(estaciones ? '200 m²' : '2 km'), findsOneWidget);
      expect(find.textContaining(estaciones ? 'Cruces/Transversales' : 'Estaciones y Edif.'), findsNothing);
      expect(find.textContaining('Total de registros clasificados'), findsOneWidget);
      expect(find.text(estaciones ? '3' : '0'), findsOneWidget);
    });
  }

}
