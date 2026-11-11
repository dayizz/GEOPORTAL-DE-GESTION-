import 'dart:math' as math;
import '../models/elemento_composicion.dart';

/// Ancho/alto mínimo (mm) de una columna/fila al redimensionarla.
const tablaMinimoMm = 3.0;

/// Número de columnas de [celdas] (la fila más larga).
int columnasTabla(List<List<String>> celdas) =>
    celdas.fold<int>(0, (n, fila) => math.max(n, fila.length));

/// Tamaños (mm) de [n] columnas o filas que reparten [total] según
/// [pesos]; los pesos que faltan o no son válidos valen el promedio.
List<double> tamanosTablaMm(List<double> pesos, int n, double total) {
  if (n <= 0) return const [];
  final validos = pesos.take(n).where((p) => p > 0).toList();
  final promedio = validos.isEmpty ? 1.0 : validos.reduce((a, b) => a + b) / validos.length;
  final completos = [
    for (var i = 0; i < n; i++) i < pesos.length && pesos[i] > 0 ? pesos[i] : promedio,
  ];
  final suma = completos.reduce((a, b) => a + b);
  return [for (final p in completos) total * p / suma];
}

List<double> anchosColumnaMm(ElementoComposicion e) =>
    tamanosTablaMm(e.tablaAnchosColumna, columnasTabla(e.tablaCeldas), e.width);

List<double> altosFilaMm(ElementoComposicion e) =>
    tamanosTablaMm(e.tablaAltosFila, e.tablaCeldas.length, e.height);

/// Cambia el ancho de la columna [columna] a [mm] sin alterar las demás:
/// la tabla crece o se encoge en la misma medida.
ElementoComposicion fijarAnchoColumna(ElementoComposicion e, int columna, double mm) {
  final anchos = anchosColumnaMm(e);
  if (columna < 0 || columna >= anchos.length) return e;
  anchos[columna] = math.max(tablaMinimoMm, mm);
  return e.copyWith(tablaAnchosColumna: anchos, width: anchos.reduce((a, b) => a + b));
}

ElementoComposicion fijarAltoFila(ElementoComposicion e, int fila, double mm) {
  final altos = altosFilaMm(e);
  if (fila < 0 || fila >= altos.length) return e;
  altos[fila] = math.max(tablaMinimoMm, mm);
  return e.copyWith(tablaAltosFila: altos, height: altos.reduce((a, b) => a + b));
}

/// Celdas con las filas/columnas del mismo tamaño (rellena las filas
/// cortas), para poder insertar y quitar por índice.
List<List<String>> _celdasRectangulares(List<List<String>> celdas) {
  final columnas = columnasTabla(celdas);
  return [
    for (final f in celdas) [...f, ...List.filled(columnas - f.length, '')],
  ];
}

/// Reubica los estilos por celda: [nuevaClave] recibe (fila, columna) y
/// devuelve su nueva posición, o `null` si la celda se elimina.
Map<String, EstiloCeldaTabla> _moverEstilos(
  Map<String, EstiloCeldaTabla> estilos,
  CeldaPos? Function(int fila, int columna) nuevaClave,
) {
  final resultado = <String, EstiloCeldaTabla>{};
  for (final entry in estilos.entries) {
    final partes = entry.key.split('_');
    final f = int.tryParse(partes.first);
    final c = int.tryParse(partes.last);
    if (f == null || c == null) continue;
    final destino = nuevaClave(f, c);
    if (destino != null) resultado[EstiloCeldaTabla.claveCelda(destino.$1, destino.$2)] = entry.value;
  }
  return resultado;
}

typedef CeldaPos = (int, int);

/// Inserta una fila vacía en [indice] (0 = arriba de todo). La fila nueva
/// mide lo mismo que la fila vecina y la tabla crece en esa medida. Los
/// estilos de las celdas se desplazan junto con su fila.
ElementoComposicion insertarFilaTabla(ElementoComposicion e, int indice) {
  final celdas = _celdasRectangulares(e.tablaCeldas);
  final columnas = math.max(1, columnasTabla(celdas));
  final i = indice.clamp(0, celdas.length);
  final altos = altosFilaMm(e);
  final referencia = altos.isEmpty ? 10.0 : altos[(i < altos.length ? i : i - 1).clamp(0, altos.length - 1)];
  return e.copyWith(
    tablaCeldas: [...celdas.take(i), List.filled(columnas, ''), ...celdas.skip(i)],
    tablaAltosFila: [...altos.take(i), referencia, ...altos.skip(i)],
    height: e.height + referencia,
    tablaEstilosCelda: _moverEstilos(e.tablaEstilosCelda, (f, c) => (f >= i ? f + 1 : f, c)),
  );
}

ElementoComposicion insertarColumnaTabla(ElementoComposicion e, int indice) {
  final celdas = _celdasRectangulares(e.tablaCeldas);
  final j = indice.clamp(0, columnasTabla(celdas));
  final anchos = anchosColumnaMm(e);
  final referencia = anchos.isEmpty ? 30.0 : anchos[(j < anchos.length ? j : j - 1).clamp(0, anchos.length - 1)];
  return e.copyWith(
    tablaCeldas: [
      for (final f in celdas) [...f.take(j), '', ...f.skip(j)],
    ],
    tablaAnchosColumna: [...anchos.take(j), referencia, ...anchos.skip(j)],
    width: e.width + referencia,
    tablaEstilosCelda: _moverEstilos(e.tablaEstilosCelda, (f, c) => (f, c >= j ? c + 1 : c)),
  );
}

/// Elimina las [filas] indicadas (siempre queda al menos una); la tabla
/// se encoge lo que medían.
ElementoComposicion eliminarFilasTabla(ElementoComposicion e, Set<int> filas) {
  final celdas = _celdasRectangulares(e.tablaCeldas);
  final quitar = filas.where((f) => f >= 0 && f < celdas.length).toSet();
  if (quitar.isEmpty || quitar.length >= celdas.length) return e;
  final altos = altosFilaMm(e);
  final nuevosAltos = [for (var i = 0; i < altos.length; i++) if (!quitar.contains(i)) altos[i]];
  return e.copyWith(
    tablaCeldas: [for (var i = 0; i < celdas.length; i++) if (!quitar.contains(i)) celdas[i]],
    tablaAltosFila: nuevosAltos,
    height: math.max(tablaMinimoMm, nuevosAltos.reduce((a, b) => a + b)),
    tablaEstilosCelda: _moverEstilos(
      e.tablaEstilosCelda,
      (f, c) => quitar.contains(f) ? null : (f - quitar.where((q) => q < f).length, c),
    ),
  );
}

ElementoComposicion eliminarColumnasTabla(ElementoComposicion e, Set<int> columnas) {
  final celdas = _celdasRectangulares(e.tablaCeldas);
  final total = columnasTabla(celdas);
  final quitar = columnas.where((c) => c >= 0 && c < total).toSet();
  if (quitar.isEmpty || quitar.length >= total) return e;
  final anchos = anchosColumnaMm(e);
  final nuevosAnchos = [for (var j = 0; j < anchos.length; j++) if (!quitar.contains(j)) anchos[j]];
  return e.copyWith(
    tablaCeldas: [
      for (final f in celdas) [for (var j = 0; j < f.length; j++) if (!quitar.contains(j)) f[j]],
    ],
    tablaAnchosColumna: nuevosAnchos,
    width: math.max(tablaMinimoMm, nuevosAnchos.reduce((a, b) => a + b)),
    tablaEstilosCelda: _moverEstilos(
      e.tablaEstilosCelda,
      (f, c) => quitar.contains(c) ? null : (f, c - quitar.where((q) => q < c).length),
    ),
  );
}
