import 'package:flutter/material.dart';
import '../../models/hoja.dart';

/// Compartido por el lienzo y la exportación para conservar número y posición.
class NumeroPaginaWidget extends StatelessWidget {
  const NumeroPaginaWidget({
    super.key,
    required this.hoja,
    required this.indice,
    required this.scale,
  });
  final Hoja hoja;
  final int indice;
  final double scale;
  @override
  Widget build(BuildContext context) {
    final numero = hoja.numeroEnHoja(indice);
    if (numero == null) return const SizedBox.shrink();
    final alineacion = switch (hoja.posicionPagina) {
      PosicionPagina.inferiorIzquierda => Alignment.bottomLeft,
      PosicionPagina.inferiorDerecha => Alignment.bottomRight,
      PosicionPagina.inferiorCentral => Alignment.bottomCenter,
      PosicionPagina.superiorIzquierda => Alignment.topLeft,
      PosicionPagina.superiorDerecha => Alignment.topRight,
      PosicionPagina.superiorCentral => Alignment.topCenter,
    };
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.all(3 * scale),
        child: Align(
          alignment: alineacion,
          child: Text(
            '$numero',
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'Arial',
              fontSize: 3.5 * scale,
            ),
          ),
        ),
      ),
    );
  }
}
