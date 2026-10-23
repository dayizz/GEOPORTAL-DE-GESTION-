import 'package:flutter/material.dart';

class TablaWidget extends StatelessWidget {
  const TablaWidget({super.key, required this.celdas});
  final List<List<String>> celdas;

  @override
  Widget build(BuildContext context) {
    if (celdas.isEmpty) return const SizedBox.shrink();
    final columnas = celdas.fold<int>(0, (n, fila) => fila.length > n ? fila.length : n);
    if (columnas == 0) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: columnas * 150.0,
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade600),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (var i = 0; i < celdas.length; i++)
              TableRow(
                decoration: BoxDecoration(color: i == 0 ? const Color(0xFFE5EBF0) : Colors.white),
                children: [
                  for (var j = 0; j < columnas; j++)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(j < celdas[i].length ? celdas[i][j] : '',
                        style: TextStyle(fontFamily: 'Arial', fontSize: 12, color: Colors.black, fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
