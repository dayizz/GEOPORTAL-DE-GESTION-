import '../../predios/models/predio.dart';

/// IDs con intersección de longitud positiva. Recibe los registros de un
/// mismo proyecto, antes de aplicar filtros de presentación o paginación.
Set<String> detectarEmpalmesKm(Iterable<Predio> predios) {
  final intervalos = predios.where((p) {
    final inicio = p.kmInicio;
    final fin = p.kmFin;
    return inicio != null && fin != null &&
        inicio.isFinite && fin.isFinite && inicio < fin;
  }).toList()
    ..sort((a, b) => a.kmInicio!.compareTo(b.kmInicio!));

  final empalmados = <String>{};
  Predio? masLargo;
  for (final actual in intervalos) {
    if (masLargo != null && actual.kmInicio! < masLargo.kmFin!) {
      empalmados.add(masLargo.id);
      empalmados.add(actual.id);
    }
    if (masLargo == null || actual.kmFin! > masLargo.kmFin!) {
      masLargo = actual;
    }
  }
  return empalmados;
}
