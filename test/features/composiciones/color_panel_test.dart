import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/color_swatch_picker.dart';
import 'package:geoportal_predios/features/composiciones/presentation/widgets/color_wheel_picker.dart';

void main() {
  testWidgets('selector de color se expande en el panel y aplica hex sin modal', (tester) async {
    String? color;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 252, child: ColorSwatchPicker(colorHex: '#FFFFFF', onChanged: (v) => color = v)))));
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    expect(find.byType(ColorWheelPanel), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(find.byType(TextField), '112233');
    await tester.pump();
    expect(color?.toUpperCase(), '#112233');
    expect(tester.takeException(), isNull);
  });
}
