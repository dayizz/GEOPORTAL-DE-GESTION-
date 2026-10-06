import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/import_normalization.dart' as norm;
import '../../estructura/models/proyecto_item.dart';
import '../../predios/models/predio.dart';

/// Cálculos puros que alimentan las gráficas de "Balance", extraídos de
/// `balance_screen.dart` para poder reutilizarlos también en el elemento
/// de tipo `grafica` de Composiciones (ver `GraficaWidget`), sin duplicar
/// la lógica en dos lugares. Todas las funciones reciben los datos ya
/// resueltos (predios, proyecto) por quien llama -no leen Riverpod aquí-
/// para poder usarse tanto desde un `ConsumerState` normal como desde el
/// árbol desconectado de `ScreenshotController.captureFromWidget`.

const sparkMonths = 6;
const sparkWeeks = 8;

enum GrupoInfraestructuraBalance {
  predios,
  estacionesEdificios,
  sinAfectacion,
  nulos,
  cruces,
  otros,
}

/// Cada registro pertenece a un solo grupo, antes de calcular su avance.
GrupoInfraestructuraBalance grupoInfraestructuraBalance(String? estructura) {
  final tipo = norm
      .stripAccents(estructura ?? '')
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), ' ');
  switch (tipo) {
    case 'ESTACION':
    case 'EDIFICIO AUXILIAR':
    case 'ZICA':
    case 'SICA': // Nombre anterior de ZICA.
      return GrupoInfraestructuraBalance.estacionesEdificios;
    case 'VIADUCTO':
    case 'TRONCAL':
    case 'DDV TRONCAL':
    case 'CARRETERA':
      return GrupoInfraestructuraBalance.predios;
    case 'SIN AFECTACION':
      return GrupoInfraestructuraBalance.sinAfectacion;
    case 'CRUCE/TRANSVERSAL':
    case 'CRUCES/TRANSVERSALES':
      return GrupoInfraestructuraBalance.cruces;
    case '':
    case 'NULL':
    case 'NULO':
      return GrupoInfraestructuraBalance.nulos;
    default:
      return GrupoInfraestructuraBalance.otros;
  }
}

Map<GrupoInfraestructuraBalance, List<Predio>> agruparInfraestructuraBalance(
  Iterable<Predio> predios,
) {
  final grupos = {
    for (final grupo in GrupoInfraestructuraBalance.values) grupo: <Predio>[],
  };
  for (final predio in predios) {
    grupos[grupoInfraestructuraBalance(predio.estructura)]!.add(predio);
  }
  return grupos;
}

/// Gestión muestra la columna "Liberación" derivándola del campo "Estatus".
/// Balance usa esta misma regla para que sus conteos coincidan con la tabla,
/// incluso en registros antiguos donde el booleano `cop` quedó desfasado.
bool predioEstaLiberado(Predio predio) =>
    Predio.estatusSimplificado(predio.rangoEstatus) == 'Liberado';

double medidaPredioBalance(Predio predio, {required bool usaM2}) =>
  usaM2 ? (predio.superficie ?? 0) : (predio.kmEfectivos ?? 0);

const mesAbrev = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

/// Una columna de 1 km dentro de una fila de cadenamiento: `km` es el
/// kilometro entero que abre el segmento `[km, km+1)` y `pct` el porcentaje
/// (0-1) de ese segmento cubierto por predios liberados según `cop`.
class CadenamientoColumna {
  final int km;
  final double pct;
  const CadenamientoColumna(this.km, this.pct);
}

/// Una fila del diagrama: un PK de cadenamiento (p.ej. "S13") con sus
/// columnas km a km ya calculadas contra Gestion.
class CadenamientoFila {
  final String codigo;
  final double pkInicioKm;
  final double pkFinKm;
  final List<CadenamientoColumna> columnas;
  const CadenamientoFila({
    required this.codigo,
    required this.pkInicioKm,
    required this.pkFinKm,
    required this.columnas,
  });
}

Map<String, int> groupCountBy<T>(
  Iterable<Predio> predios,
  T Function(Predio) selector,
) {
  final result = <String, int>{};
  for (final predio in predios) {
    final key = selector(predio).toString();
    result[key] = (result[key] ?? 0) + 1;
  }
  return result;
}

/// Fecha de inicio (ventana rodante de 7 días) de la semana en el índice
/// `idx` dentro de una ventana de `totalSemanas`: 0 es la semana más
/// antigua y `totalSemanas - 1` la semana actual (últimos 7 días).
DateTime weekStart(int idx, {int totalSemanas = sparkWeeks}) {
  final now = DateTime.now();
  final hoy = DateTime(now.year, now.month, now.day);
  final semanasAtras = totalSemanas - 1 - idx;
  return hoy.subtract(Duration(days: 7 * semanasAtras + 6));
}

/// % acumulado de `predios` que Gestión muestra como liberados, según
/// `Estatus`, y cuya fecha de
/// liberación (`copFecha`, o `updatedAt`/`createdAt` como respaldo si no
/// se capturó) cae antes de cada fecha de corte en `finesDePeriodo`
/// (exclusiva). A diferencia de un conteo por periodo, esto incluye
/// liberaciones anteriores a la ventana visible, para que la barra
/// represente el avance real acumulado a esa fecha, no solo lo nuevo.
List<double> cumulativePctLiberado(
  List<Predio> predios, {
  required List<DateTime> finesDePeriodo,
}) {
  final total = predios.length;
  if (total == 0) return List.filled(finesDePeriodo.length, 0);

  final liberados = predios.where(predioEstaLiberado).toList();
  return finesDePeriodo.map((finExclusivo) {
    final acumulados = liberados.where((p) {
      final fecha = p.copFecha ?? p.updatedAt ?? p.createdAt;
      return fecha.isBefore(finExclusivo);
    }).length;
    return acumulados / total * 100;
  }).toList();
}

/// Porcentaje acumulado por kilómetros; conserva el criterio temporal de Balance.
List<double> cumulativePctKmLiberado(
  List<Predio> predios, {
  required double longitudKm,
  required List<DateTime> finesDePeriodo,
}) {
  if (longitudKm <= 0) return List.filled(finesDePeriodo.length, 0);
  return finesDePeriodo.map((fin) {
    final km = predios.where((p) => predioEstaLiberado(p) &&
        (p.copFecha ?? p.updatedAt ?? p.createdAt).isBefore(fin))
        .fold<double>(0, (sum, p) => sum + (p.kmEfectivos ?? 0));
    return km / longitudKm * 100;
  }).toList();
}

List<double> pctMedidaLiberadaPorPeriodo(List<Predio> predios, {
  required double medidaTotal,
  double Function(Predio)? medida,
  required List<DateTime> inicios,
  required List<DateTime> fines,
}) {
  return List.generate(inicios.length, (i) {
    if (medidaTotal <= 0) return 0.0;
    final medidaLiberada = predios.where((p) {
      final fecha = p.copFecha ?? p.rangoEstatusFecha;
      return predioEstaLiberado(p) && fecha != null &&
          !fecha.isBefore(inicios[i]) && fecha.isBefore(fines[i]);
    }).fold<double>(0, (sum, p) => sum + (medida?.call(p) ?? p.kmEfectivos ?? 0));
    return medidaLiberada / medidaTotal * 100;
  });
}

String _normalizeLiberacionToken(String? raw) {
  if (raw == null) return '';
  return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

String resolveTipoLiberacion(Predio predio) {
  final gestion = _normalizeLiberacionToken(predio.tipoLiberacion);
  if (gestion.contains('AOP')) return 'AOP';
  if (gestion.contains('DOT')) return 'DOT';
  if (gestion.contains('COP')) return 'COP';

  final firmado = _normalizeLiberacionToken(predio.copFirmado);
  if (firmado.contains('AOP')) return 'AOP';
  if (firmado.contains('DOT')) return 'DOT';
  if (firmado.contains('COP')) return 'COP';

  if (predioEstaLiberado(predio)) {
    return (predio.copFirmado ?? '').trim().isNotEmpty ? 'COP' : 'Sin tipo';
  }
  return 'Sin liberación';
}

String _normalizeTipoLiberacionLabel(String tipo) {
  final t = _normalizeLiberacionToken(tipo);
  if (t.contains('AOP')) return 'AOP';
  if (t.contains('DOT')) return 'DOT';
  if (t.contains('COP')) return 'COP';
  if (tipo == 'Sin tipo / Sin liberación') return 'Sin tipo / Sin liberación';
  if (tipo == 'Sin tipo') return 'Sin tipo';
  if (tipo == 'Sin liberación') return 'Sin liberación';
  return tipo;
}

/// Conteo por tipo de liberación (AOP/DOT/COP/Sin tipo/Sin liberación),
/// con "Sin tipo" y "Sin liberación" consolidados en una sola categoría
/// "Sin tipo / Sin liberación" para no saturar la leyenda de la dona.
Map<String, int> porTipoLiberacionConsolidado(List<Predio> predios) {
  final porTipoLiberacion = <String, int>{};
  for (final predio in predios) {
    final tipo = resolveTipoLiberacion(predio);
    porTipoLiberacion[tipo] = (porTipoLiberacion[tipo] ?? 0) + 1;
  }
  final sinTipo = porTipoLiberacion.remove('Sin tipo') ?? 0;
  final sinLiberacion = porTipoLiberacion.remove('Sin liberación') ?? 0;
  final sinTipoSinLiberacion = sinTipo + sinLiberacion;
  if (sinTipoSinLiberacion > 0) {
    porTipoLiberacion['Sin tipo / Sin liberación'] = sinTipoSinLiberacion;
  }
  return porTipoLiberacion;
}

/// Conteo del tipo capturado únicamente para registros liberados.
Map<String, int> tiposDeRegistrosLiberados(Iterable<Predio> predios) {
  final conteos = <String, int>{
    'COP': 0,
    'DOT': 0,
    'AOP': 0,
    'EXPROPIACION': 0,
    'ANUENCIA POR OFICIO': 0,
    'MINUTA': 0,
    'SIN TIPO': 0,
  };
  for (final predio in predios.where(predioEstaLiberado)) {
    var tipo = norm.stripAccents(predio.tipoLiberacion ?? '')
        .trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    if (tipo == 'ESPROPIACION') tipo = 'EXPROPIACION';
    if (!conteos.containsKey(tipo)) tipo = 'SIN TIPO';
    conteos[tipo] = conteos[tipo]! + 1;
  }
  return conteos;
}

Color tipoLiberacionColor(String tipo) {
  switch (norm.stripAccents(tipo).trim().toUpperCase()) {
    case 'EXPROPIACION':
    case 'ESPROPIACION':
      return Colors.deepPurple;
    case 'ANUENCIA POR OFICIO':
      return Colors.teal;
    case 'MINUTA':
      return Colors.orange;
  }
  final normalized = _normalizeTipoLiberacionLabel(tipo);
  switch (normalized) {
    case 'COP':
      return AppColors.secondary;
    case 'DOT':
      return AppColors.info;
    case 'AOP':
      return AppColors.primary;
    case 'Sin tipo':
      return AppColors.warning;
    case 'Sin liberación':
      return AppColors.danger;
    case 'Sin tipo / Sin liberación':
      return AppColors.warning;
    default:
      return Colors.grey;
  }
}

/// % liberado por segmento/tramo/frente (0-100), en el mismo orden que
/// `porTramo.keys`, usando la misma regla que la columna "Liberación" de Gestión.
List<double> pctLiberadoPorTramo(
  Map<String, int> porTramo,
  List<Predio> todosPredios,
) {
  return porTramo.entries.map((e) {
    final liberadosTramo = todosPredios
        .where((p) => p.tramo == e.key && predioEstaLiberado(p))
        .length;
    return e.value > 0 ? liberadosTramo / e.value * 100 : 0.0;
  }).toList();
}

/// Ordena el conteo por "Estatus" según `Predio.rangoEstatusOpciones`
/// (el catálogo vigente, mismo orden que el dropdown en "Editar predio"),
/// para que la dona y su leyenda sean siempre consistentes entre
/// renders. Cualquier valor fuera del catálogo (dato legado) se agrega al
/// final, ordenado alfabéticamente.
List<MapEntry<String, int>> ordenarRangoEstatus(Map<String, int> porRango) {
  final conteos = {for (final opcion in Predio.rangoEstatusOpciones) opcion: 0};
  String normalizar(String valor) => norm.stripAccents(valor).trim().toUpperCase();
  for (final entry in porRango.entries) {
    final coincidencias = Predio.rangoEstatusOpciones.where(
      (opcion) => normalizar(opcion) == normalizar(entry.key),
    );
    final clave = coincidencias.isEmpty ? entry.key : coincidencias.first;
    conteos[clave] = (conteos[clave] ?? 0) + entry.value;
  }
  return conteos.entries.toList();
}

/// Extrae solo los dígitos de un T/F/S o numero_id de cadenamiento y los
/// normaliza sin ceros a la izquierda (p.ej. "S16" -> "16", "016" -> "16"),
/// para poder comparar ambos por número sin importar prefijo de letra.
String soloDigitos(String value) {
  final digits = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  return int.parse(digits).toString();
}

Color colorParaPctLiberado(double pct) {
  if (pct >= 0.9) return AppColors.secondary;
  if (pct >= 0.5) return AppColors.warning;
  return AppColors.danger;
}

String formatKmLength(double km) {
  if (km == km.roundToDouble()) return '${km.round()} km';
  return '${km.toStringAsFixed(1)} km';
}

/// Aplana el cadenamiento del proyecto (uno o varios bloques de
/// Segmento/Tramo/Frente, cada uno con varios PK's) en filas del diagrama,
/// calculando para cada km entero el % cubierto por predios de Gestión en
/// que Gestión muestra como liberados en la columna "Liberación".
///
/// El PK de cada fila se identifica por letra+numero (p.ej. "S13" =
/// Segmento + numero_id "13"), el mismo formato que ya usa "Editar
/// predio" para T/F/S (ver `_buildTramoValue` en `predio_form_screen.dart`),
/// así que basta comparar contra `predio.tramo`.
List<CadenamientoFila> buildFilasCadenamiento(
  ProyectoItem? proyecto,
  List<Predio> proyectoPredios,
) {
  if (proyecto == null) return const [];
  final filas = <CadenamientoFila>[];

  for (final cadenamiento in proyecto.cadenamientos) {
    for (final pk in cadenamiento.pks) {
      final ini = norm.normalizeKmValue(pk.pkInicio);
      final fin = norm.normalizeKmValue(pk.pkFin);
      if (ini == null || fin == null || fin <= ini) continue;

      final codigo = '${cadenamiento.letra}${pk.numeroId}'.trim().toUpperCase();
      if (codigo.isEmpty) continue;

      final numeroPk = soloDigitos(pk.numeroId);
      final esAlfanumerico = RegExp(r'[a-zA-Z]').hasMatch(pk.numeroId);
      final predios = proyectoPredios
          .where(
            (p) =>
                (esAlfanumerico
                    ? p.tramo.trim().toUpperCase() == codigo
                    : numeroPk.isNotEmpty && soloDigitos(p.tramo) == numeroPk &&
                        !RegExp(r'[a-zA-Z]').hasMatch(
                          p.tramo.trim().replaceFirst(RegExp(r'^[STFstf]'), ''),
                        )) &&
                p.kmInicio != null &&
                p.kmFin != null,
          )
          .toList(growable: false);

      final primeraColumna = ini.floor();
      final ultimaColumna = fin.ceil() - 1;
      final columnas = <CadenamientoColumna>[];

      for (var km = primeraColumna; km <= ultimaColumna; km++) {
        final segInicio = math.max(km.toDouble(), ini);
        final segFin = math.min(km + 1.0, fin);
        final anchoSegmento = segFin - segInicio;
        if (anchoSegmento <= 0) continue;

        var liberadoLen = 0.0;
        for (final p in predios) {
          final pIni = math.min(p.kmInicio!, p.kmFin!);
          final pFin = math.max(p.kmInicio!, p.kmFin!);
          final solapeIni = math.max(pIni, segInicio);
          final solapeFin = math.min(pFin, segFin);
          final solape = solapeFin - solapeIni;
          if (solape <= 0) continue;
          if (predioEstaLiberado(p)) {
            liberadoLen += solape;
          }
        }

        final pct = (liberadoLen / anchoSegmento).clamp(0.0, 1.0);
        columnas.add(CadenamientoColumna(km, pct));
      }

      filas.add(
        CadenamientoFila(
          codigo: codigo,
          pkInicioKm: ini,
          pkFinKm: fin,
          columnas: columnas,
        ),
      );
    }
  }

  filas.sort((a, b) => a.pkInicioKm.compareTo(b.pkInicioKm));
  return filas;
}
