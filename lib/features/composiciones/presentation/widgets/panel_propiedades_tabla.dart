import 'package:flutter/material.dart';

class PanelPropiedadesTabla extends StatefulWidget {
  const PanelPropiedadesTabla({super.key, this.inicial, required this.onChanged});
  final ValueChanged<List<List<String>>> onChanged;
  final List<List<String>>? inicial;
  @override
  State<PanelPropiedadesTabla> createState() => _PanelPropiedadesTablaState();
}

class _PanelPropiedadesTablaState extends State<PanelPropiedadesTabla> {
  late List<List<TextEditingController>> celdas;
  @override
  void initState() {
    super.initState();
    final datos = widget.inicial?.isNotEmpty == true ? widget.inicial! : [
      ['Columna 1', 'Columna 2', 'Columna 3'], ['', '', ''], ['', '', ''],
    ];
    final columnas = datos.fold<int>(1, (n, fila) => fila.length > n ? fila.length : n);
    celdas = datos.map((fila) => List.generate(columnas, (j) => TextEditingController(text: j < fila.length ? fila[j] : ''))).toList();
  }
  @override
  void dispose() {
    for (final fila in celdas) {
      for (final celda in fila) { celda.dispose(); }
    }
    super.dispose();
  }
  void _emitir() => widget.onChanged(celdas.map((fila) => fila.map((c) => c.text).toList()).toList());
  @override
  Widget build(BuildContext context) => Column(children: [
        const Text('La primera fila se muestra como encabezado.'),
        Wrap(spacing: 8, children: [
          TextButton(onPressed: () { setState(() => celdas.add(List.generate(celdas.first.length, (_) => TextEditingController()))); _emitir(); }, child: const Text('+ Fila')),
          TextButton(onPressed: () { setState(() { for (final fila in celdas) { fila.add(TextEditingController()); } }); _emitir(); }, child: const Text('+ Columna')),
          TextButton(onPressed: celdas.length <= 1 ? null : () { setState(() { for (final c in celdas.removeLast()) { c.dispose(); } }); _emitir(); }, child: const Text('Quitar última fila')),
          TextButton(onPressed: celdas.first.length <= 1 ? null : () { setState(() { for (final fila in celdas) { fila.removeLast().dispose(); } }); _emitir(); }, child: const Text('Quitar última columna')),
        ]),
        const SizedBox(height: 8),
        SizedBox(height: 300, child: SingleChildScrollView(
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Column(children: [
            for (final fila in celdas) Row(children: [
              for (final celda in fila) SizedBox(width: 180, child: Padding(
                padding: const EdgeInsets.all(3),
                child: TextField(controller: celda, onChanged: (_) => _emitir(), decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
              )),
            ]),
          ])),
        )),
      ]);
}
