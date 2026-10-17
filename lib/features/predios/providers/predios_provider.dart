import '../utils/codigo_division.dart';
import '../../estructura/models/proyecto_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/predios_repository.dart';
import '../models/predio.dart';
import 'local_predios_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../estructura/providers/proyectos_provider.dart';

// Filtros activos
class PrediosFiltros {
  final String busqueda;
  final String? usoSuelo;
  final String? zona;
  final String? propietarioId;
  final String? proyecto; // TQI, TSNL, TAP, TMQ, etc.

  const PrediosFiltros({
    this.busqueda = '',
    this.usoSuelo,
    this.zona,
    this.propietarioId,
    this.proyecto,
  });

  PrediosFiltros copyWith({
    String? busqueda,
    String? usoSuelo,
    String? zona,
    String? propietarioId,
    String? proyecto,
    bool clearUsoSuelo = false,
    bool clearZona = false,
    bool clearPropietario = false,
    bool clearProyecto = false,
  }) {
    return PrediosFiltros(
      busqueda: busqueda ?? this.busqueda,
      usoSuelo: clearUsoSuelo ? null : (usoSuelo ?? this.usoSuelo),
      zona: clearZona ? null : (zona ?? this.zona),
      propietarioId: clearPropietario
          ? null
          : (propietarioId ?? this.propietarioId),
      proyecto: clearProyecto ? null : (proyecto ?? this.proyecto),
    );
  }
}

final prediosFiltrosProvider = StateProvider<PrediosFiltros>(
  (ref) => const PrediosFiltros(),
);

/// La identidad y los permisos forman parte de la suscripción. Al cambiar
/// de usuario se cancela la fuente anterior y se descarta su contenido.
final prediosRemotosProvider = StreamProvider<List<Predio>>((ref) {
  final uid = ref.watch(authStateProvider.select((auth) => auth.valueOrNull?.uid));
  if (uid == null) return Stream.value(const <Predio>[]);
  final proyecto = ref.watch(proyectoActivoProvider);
  final permitidos = ref.watch(currentUserAssignedProjectsProvider);
  final todos = ref.watch(canAccessAllProjectsProvider);
  return ref
      .watch(prediosRepositoryProvider)
      .watchPredios(
        proyecto: proyecto,
        proyectosPermitidos: todos ? null : permitidos,
      );
});

final _normalizarDivisionProvider = Provider<Predio Function(Predio)>((ref) {
  final proyectos = ref.watch(proyectosProvider).valueOrNull ?? <ProyectoItem>[];
  final cache = Expando<Predio>('divisionNormalizada');
  return (predio) => cache[predio] ??= _normalizarDivision(predio, proyectos);
});

final prediosCombinadosProvider = FutureProvider<List<Predio>>((ref) async {
  final remotos = ref.watch(prediosRemotosProvider.future);
  final locales = ref.watch(localPrediosProvider);
  final proyectos =
      ref.watch(proyectosProvider).valueOrNull ?? <ProyectoItem>[];
  final todos = ref.watch(canAccessAllProjectsProvider);
  final permitidos = ref.watch(currentUserAssignedProjectsProvider).toSet();
  final sesion = ref.watch(proyectoActivoProvider);
  final codigos = proyectos.map((p) => p.nombre.trim().toUpperCase()).toList();
  final normalizar = ref.watch(_normalizarDivisionProvider);
  final uid = ref.watch(authStateProvider.select((auth) => auth.valueOrNull?.uid));
  if (uid == null && !localOnlyAuthMode) return const <Predio>[];
  final datos = await remotos;
  final claves = datos.map((p) => p.claveCatastral).toSet();
  final merged = [
    ...datos,
    ...locales.where((p) => !claves.contains(p.claveCatastral)),
  ];
  return merged
      .where((p) {
        final codigo = _extractProjectoFromPredio(p, codigos);
        return (todos || permitidos.contains(codigo)) &&
            (sesion == null || codigo == sesion);
      })
      .map(normalizar)
      .toList(growable: false);
});

final prediosListProvider = FutureProvider<List<Predio>>((ref) async {
  final filtros = ref.watch(prediosFiltrosProvider);
  final datos = ref.watch(prediosCombinadosProvider.future);
  final codigos = ref.watch(proyectosCodigosProvider);
  final predios = await datos;
  return predios
      .where((p) {
        if (filtros.proyecto != null &&
            _extractProjectoFromPredio(p, codigos) != filtros.proyecto) {
          return false;
        }
        if (filtros.usoSuelo != null && p.usoSuelo != filtros.usoSuelo) {
          return false;
        }
        if (filtros.zona != null && p.zona != filtros.zona) return false;
        if (filtros.propietarioId != null &&
            p.propietarioId != filtros.propietarioId) {
          return false;
        }
        final q = filtros.busqueda.trim().toLowerCase();
        return q.isEmpty ||
            p.claveCatastral.toLowerCase().contains(q) ||
            (p.propietarioNombre?.toLowerCase().contains(q) ?? false) ||
            (p.ejido?.toLowerCase().contains(q) ?? false);
      })
      .toList(growable: false);
});

/// Extrae el proyecto de un predio según sus campos. [proyectosValidos] es la
/// lista vigente de códigos dados de alta en Estructura (Firestore).
String _extractProjectoFromPredio(
  Predio predio,
  List<String> proyectosValidos,
) {
  final proyectoDirecto = predio.proyecto?.trim().toUpperCase();
  if (proyectoDirecto != null && proyectoDirecto.isNotEmpty) {
    // 'TQM' es un alias heredado (typo histórico); el código correcto es
    // 'TMQ' (Tren México-Querétaro).
    if (proyectoDirecto == 'TQM' && proyectosValidos.contains('TMQ')) {
      return 'TMQ';
    }
    return proyectoDirecto;
  }

  final contenido = [
    predio.claveCatastral,
    predio.ejido ?? '',
    predio.poligonoDwg ?? '',
    predio.oficio ?? '',
    predio.pdfUrl ?? '',
    predio.copFirmado ?? '',
  ].join(' ').toUpperCase();

  for (final proyecto in proyectosValidos) {
    if (contenido.contains(proyecto)) return proyecto;
  }
  if (contenido.contains('TQM') && proyectosValidos.contains('TMQ')) {
    return 'TMQ';
  }

  return 'Sin proyecto';
}

final prediosMapaProvider = FutureProvider<List<Predio>>((ref) async {
  return ref.watch(prediosCombinadosProvider.future);
});

final prediosMapaByIdProvider = Provider<Map<String, Predio>>((ref) {
  final prediosAsync = ref.watch(prediosMapaProvider);
  return prediosAsync.maybeWhen(
    data: (predios) => {for (final predio in predios) predio.id: predio},
    orElse: () => const {},
  );
});

final predioDetalleProvider = FutureProvider.family<Predio?, String>((
  ref,
  id,
) async {
  final proyectos =
      ref.watch(proyectosProvider).valueOrNull ?? <ProyectoItem>[];
  final locales = ref.watch(localPrediosProvider);
  for (final local in locales) {
    if (local.id == id) return _normalizarDivision(local, proyectos);
  }
  final cached = ref.watch(prediosCombinadosProvider.select((datos) {
    for (final predio in datos.valueOrNull ?? <Predio>[]) {
      if (predio.id == id) return predio;
    }
    return null;
  }));
  if (cached != null && cached.propietarioId == null) return cached;
  final repo = ref.read(prediosRepositoryProvider);
  try {
    final predio = await repo.getPredioById(id);
    return predio == null ? null : _normalizarDivision(predio, proyectos);
  } catch (_) {
    return null;
  }
});

final estadisticasProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final locales = ref.watch(localPrediosProvider);
  final repo = ref.read(prediosRepositoryProvider);
  try {
    final remotas = await repo.getEstadisticas();
    final totalRemoto = (remotas['total'] as int?) ?? 0;
    final total = totalRemoto + locales.length;
    final superficieLocal = locales.fold<double>(
      0,
      (sum, p) => sum + (p.superficie ?? 0),
    );
    return {
      ...remotas,
      'total': total,
      'superficie_total':
          ((remotas['superficie_total'] as num?)?.toDouble() ?? 0) +
          superficieLocal,
    };
  } catch (_) {
    final porUso = <String, int>{};
    var superficie = 0.0;
    for (final p in locales) {
      porUso[p.tipoPropiedad] = (porUso[p.tipoPropiedad] ?? 0) + 1;
      superficie += p.superficie ?? 0;
    }
    return {
      'total': locales.length,
      'por_uso_suelo': porUso,
      'superficie_total': superficie,
    };
  }
});

Predio _normalizarDivision(Predio predio, List<ProyectoItem> proyectos) {
  final codigo = _extractProjectoFromPredio(
    predio,
    proyectos.map((p) => p.nombre.trim().toUpperCase()).toList(),
  );
  final coincidencias = proyectos.where(
    (p) => p.nombre.trim().toUpperCase() == codigo,
  );
  final proyecto = coincidencias.isEmpty ? null : coincidencias.first;
  final tramo = normalizarCodigoDivision(predio.tramo, proyecto);
  return tramo == predio.tramo ? predio : predio.copyWith(tramo: tramo);
}
