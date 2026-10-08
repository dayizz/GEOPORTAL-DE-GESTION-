import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/reportes/presentation/widgets/resumen_tramos_widget.dart';
import 'package:geoportal_predios/features/reportes/presentation/widgets/balance_chart_widgets.dart';
import 'package:geoportal_predios/features/reportes/utils/resumen_tramos.dart';
import 'package:geoportal_predios/features/reportes/utils/balance_calculos.dart';

void main() {
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final mode in ['predios', 'cruces', 'm2']) {
      testWidgets('TFS $mode layout at $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
          child: ResumenTramosWidget(
            filas: [ResumenTramoBalance('S13', 0, 55, [])],
            esCruces: mode == 'cruces', usaM2: mode == 'm2',
          ),
        ))));
        final table = tester.getRect(find.byType(DataTable));
        final chart = tester.getRect(find.byType(LinearProgressIndicator));
        if (width < 700) {
          expect(chart.top, greaterThan(table.bottom));
          expect(chart.right, lessThanOrEqualTo(width));
          expect(find.byType(Scrollbar), findsOneWidget);
        } else {
          expect(chart.left, greaterThan(table.right));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Mobile chainage has a persistent, working horizontal scrollbar', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: buildCadenamientoFilaCard(
      CadenamientoFila(codigo: 'S13', pkInicioKm: 0, pkFinKm: 50,
        columnas: List.generate(50, (i) => CadenamientoColumna(i, .5))),
    ))));
    final bar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(bar.thumbVisibility, isTrue);
    expect(bar.trackVisibility, isTrue);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(bar.controller!.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
