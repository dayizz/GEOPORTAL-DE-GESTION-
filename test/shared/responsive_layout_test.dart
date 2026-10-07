import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:geoportal_predios/features/auth/providers/auth_provider.dart';
import 'package:geoportal_predios/features/reportes/presentation/widgets/balance_chart_widgets.dart';
import 'package:geoportal_predios/shared/widgets/app_scaffold.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('Balance fits a $width pixel viewport', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          buildEstatusChartBlock(
            titulo: 'Tipo de liberación (liberados)',
            entries: const [MapEntry('ANUENCIA POR OFICIO', 20), MapEntry('SIN TIPO', 0)],
            total: 20, colorFn: (_) => Colors.green, fmtInt: NumberFormat('#,##0'),
          ),
          buildTipoPropiedadCard(titulo: 'SOCIAL / DOMINIO PLENO', predios: [], fmtInt: NumberFormat('#,##0')),
        ]),
      ))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ANUENCIA POR OFICIO: 20'), findsOneWidget);
    });
  }
  testWidgets('Mobile navigation opens all destinations in a drawer', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserPerfilProvider.overrideWithValue('Administrador')],
      child: const MaterialApp(home: AppScaffold(currentIndex: 0, title: 'Mapa', child: SizedBox.expand())),
    ));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
