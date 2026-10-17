import '../../predios/models/predio.dart';

/// Orden natural para códigos como S2, S10, S15B y S15B2.
int compararCodigosDivision(String a, String b) {
  String limpiar(String codigo) =>
      codigo.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  final x = limpiar(a);
  final y = limpiar(b);
  bool sinDivision(String codigo) => codigo.isEmpty || codigo == 'S/T';
  if (sinDivision(x) != sinDivision(y)) return sinDivision(x) ? 1 : -1;
  final partes = RegExp(r'\d+|\D+');
  final partesX = partes.allMatches(x).map((m) => m.group(0)!).toList();
  final partesY = partes.allMatches(y).map((m) => m.group(0)!).toList();
  for (var i = 0; i < partesX.length && i < partesY.length; i++) {
    final numeroX = int.tryParse(partesX[i]);
    final numeroY = int.tryParse(partesY[i]);
    final orden = numeroX != null && numeroY != null
        ? numeroX.compareTo(numeroY)
        : partesX[i].compareTo(partesY[i]);
    if (orden != 0) return orden;
  }
  return partesX.length.compareTo(partesY.length);
}

/// Agrupa por T/F/S y ordena por KM dentro de cada grupo. Los kilómetros
/// ausentes quedan al final de su grupo, antes de la siguiente división.
int compararPrediosGestion(Predio a, Predio b) {
  final division = compararCodigosDivision(a.tramo, b.tramo);
  if (division != 0) return division;
  int compararKm(double? x, double? y) {
    final validoX = x != null && x.isFinite;
    final validoY = y != null && y.isFinite;
    if (!validoX) return validoY ? 1 : 0;
    if (!validoY) return -1;
    return x.compareTo(y);
  }

  final inicio = compararKm(a.kmInicio, b.kmInicio);
  if (inicio != 0) return inicio;
  final fin = compararKm(a.kmFin, b.kmFin);
  if (fin != 0) return fin;
  final clave = a.claveCatastral.compareTo(b.claveCatastral);
  return clave != 0 ? clave : a.id.compareTo(b.id);
}
