import '../../estructura/models/proyecto_item.dart';
import '../../predios/models/predio.dart';
import '../../reportes/utils/balance_calculos.dart';
import '../../reportes/utils/resumen_tramos.dart';

/// Predios y cadenamiento de un proyecto (código), resueltos por quien
/// tiene acceso a los providers (el editor), para que cada gráfica use el
/// proyecto que tiene elegido y no solo el de la composición.
typedef ResolverDatosGrafica = ({List<Predio> predios, ProyectoItem? proyecto}) Function(String? proyecto);

/// Filtro "Ver como" de una gráfica, con los mismos valores que el
/// selector de `BalanceScreen`: `null` = proyecto completo.
const filtroGraficaEstaciones = 'grupo:estaciones';
const filtroGraficaCruces = 'grupo:cruces';
const _prefijoSegmento = 'segmento:';

String filtroGraficaSegmento(String segmento) => '$_prefijoSegmento$segmento';

/// Segmento/tramo/frente del [filtro], o `null` si no filtra por segmento.
String? segmentoDeFiltroGrafica(String? filtro) =>
    filtro != null && filtro.startsWith(_prefijoSegmento)
        ? filtro.substring(_prefijoSegmento.length)
        : null;

/// Segmentos/tramos/frentes disponibles en [prediosProyecto], igual que
/// los lista Balance (sin los códigos S15/15/S15A que Balance excluye).
List<String> segmentosGrafica(List<Predio> prediosProyecto, ProyectoItem? proyecto) {
  final segmentos = prediosProyecto
      .where((p) => p.tramo.isNotEmpty)
      .map((p) => claveTramoBalance(p.tramo, proyecto))
      .where((c) => c != 'S15' && c != '15' && c != 'S15A')
      .toSet()
      .toList()
    ..sort();
  return segmentos;
}

/// Predios que grafica un elemento con [filtro]: mismo criterio que
/// Balance (primero el segmento, luego el grupo de infraestructura).
List<Predio> prediosGrafica(List<Predio> prediosProyecto, ProyectoItem? proyecto, String? filtro) {
  final segmento = segmentoDeFiltroGrafica(filtro);
  final registros = segmento == null
      ? prediosProyecto
      : prediosProyecto.where((p) => claveTramoBalance(p.tramo, proyecto) == segmento).toList();
  final grupo = switch (filtro) {
    filtroGraficaEstaciones => GrupoInfraestructuraBalance.estacionesEdificios,
    filtroGraficaCruces => GrupoInfraestructuraBalance.cruces,
    _ => GrupoInfraestructuraBalance.predios,
  };
  return agruparInfraestructuraBalance(registros)[grupo]!;
}
