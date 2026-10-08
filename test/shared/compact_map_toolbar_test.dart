import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoportal_predios/features/mapa/presentation/widgets/compact_map_toolbar.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0, 600.0]) {
    testWidgets('Nine map actions stay aligned and tappable at $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tapped = <int>[];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(
        padding: const EdgeInsets.all(8),
        child: CompactMapToolbar(children: List.generate(9, (i) => IconButton(
          key: ValueKey(i), icon: const Icon(Icons.map), onPressed: () => tapped.add(i),
        ))),
      ))));
      final firstY = tester.getCenter(find.byKey(const ValueKey(0))).dy;
      for (var i = 0; i < 9; i++) {
        final button = find.byKey(ValueKey(i));
        expect(tester.getCenter(button).dy, closeTo(firstY, 0.1));
        await tester.tap(button);
      }
      expect(tapped, List.generate(9, (i) => i));
      expect(tester.takeException(), isNull);
    });
  }
}
