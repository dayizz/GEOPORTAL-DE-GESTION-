import 'package:flutter/material.dart';

/// Mantiene todas las herramientas en una fila y ajusta cada botón al ancho.
class CompactMapToolbar extends StatelessWidget {
  const CompactMapToolbar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: FittedBox(child: children[i]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
