import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/composiciones/models/hoja.dart';
import 'package:geoportal_predios/features/composiciones/models/elemento_composicion.dart';
import 'package:geoportal_predios/features/composiciones/utils/limites_hoja.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/herramienta_hoja_dialog.dart';

void main() {
  final hoja = Hoja.nueva(nombre: 'Prueba');
  for (final angle in [0.0, 45.0, 90.0, 135.0]) {
    test('encaja elementos grandes y rotados a $angle grados', () {
      final e = ElementoComposicion.forma(
        figuraTipo: TipoFigura.rectangulo,
        x: -70,
        y: 280,
        width: 400,
        height: 250,
      ).copyWith(rotacion: angle);
      final result = limitarElementoAHoja(e, hoja);
      final radians = angle * math.pi / 180;
      final halfW =
          (result.width * math.cos(radians).abs() +
              result.height * math.sin(radians).abs()) /
          2;
      final halfH =
          (result.width * math.sin(radians).abs() +
              result.height * math.cos(radians).abs()) /
          2;
      final cx = result.x + result.width / 2, cy = result.y + result.height / 2;
      expect(cx - halfW, greaterThanOrEqualTo(10 - 1e-8));
      expect(cx + halfW, lessThanOrEqualTo(200 + 1e-8));
      expect(cy - halfH, greaterThanOrEqualTo(10 - 1e-8));
      expect(cy + halfH, lessThanOrEqualTo(287 + 1e-8));
      expect(result.width / result.height, closeTo(e.width / e.height, 1e-8));
    });
  }
  test('margen cero permite colocación libre', () {
    final e = ElementoComposicion.texto(x: -20, y: 400);
    expect(limitarElementoAHoja(e, hoja.copyWith(margenMm: 0)), same(e));
  });
  test('mover dentro del margen conserva tamaño y ubicación', () {
    final e = ElementoComposicion.forma(
      figuraTipo: TipoFigura.rectangulo,
      x: 12,
      y: 30,
      width: 50,
      height: 25,
    );
    final result = limitarElementoAHoja(e, hoja);
    expect(result.x, e.x);
    expect(result.y, e.y);
    expect(result.width, e.width);
    expect(result.height, e.height);
  });
  testWidgets('medidas, orientación y margen decimal con validación', (
    tester,
  ) async {
    HerramientaHojaResultado? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await mostrarHerramientaHojaDialog(
                  context,
                  hoja: hoja.copyWith(margenMm: 12.5),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('A4 (210 × 297 mm)'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Horizontal').last);
    await tester.pumpAndSettle();
    expect(find.text('A4 (297 × 210 mm)'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '200');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(
      find.text('El margen debe dejar espacio útil en la hoja.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), '12,5');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(result!.horizontal, isTrue);
    expect(result!.margenMm, 12.5);
    expect(tester.takeException(), isNull);
  });
}
