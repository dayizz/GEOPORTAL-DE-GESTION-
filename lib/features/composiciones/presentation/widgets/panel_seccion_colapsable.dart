import 'package:flutter/material.dart';

/// Sección colapsable (tipo acordeón) usada en los paneles de propiedades
/// del editor de composiciones para agrupar controles afines y reducir el
/// listado vertical continuo de opciones.
class PanelSeccionColapsable extends StatefulWidget {
  const PanelSeccionColapsable({
    super.key,
    required this.titulo,
    required this.children,
    this.icono,
    this.inicialmenteExpandido = true,
  });

  final String titulo;
  final IconData? icono;
  final bool inicialmenteExpandido;
  final List<Widget> children;

  @override
  State<PanelSeccionColapsable> createState() =>
      _PanelSeccionColapsableState();
}

class _PanelSeccionColapsableState extends State<PanelSeccionColapsable> {
  late bool _expandido = widget.inicialmenteExpandido;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE3E5E9)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: Row(
                children: [
                  if (widget.icono != null) ...[
                    Icon(
                      widget.icono,
                      size: 15,
                      color: const Color(0xFF5B6270),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expandido ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(Icons.keyboard_arrow_down, size: 18),
                  ),
                ],
              ),
            ),
          ),
          if (_expandido)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
        ],
      ),
    );
  }
}
