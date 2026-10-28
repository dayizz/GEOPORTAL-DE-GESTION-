import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/import_normalization.dart' as import_norm;
import '../../auth/providers/auth_provider.dart';
import '../../carga/data/archivos_geojson_repository.dart';
import '../../carga/providers/carga_provider.dart';
import '../../carga/utils/geojson_mapper.dart';
import 'mapa_provider.dart';

/// Archivos GeoJSON guardados en Firestore que el usuario [uid] puede ver:
/// todos si es administrador/supervisor, o solo los propios y los de sus
/// proyectos asignados. Devuelve `null` si el usuario cambió durante la
/// consulta (el resultado ya no aplica).
Future<List<ImportedFile>?> cargarArchivosGuardadosVisibles(WidgetRef ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return null;
  final uid = user.uid;

  Map<String, dynamic>? profile;
  try {
    profile = await ref
        .read(currentUserProfileProvider.future)
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    profile = null;
  }
  if (ref.read(currentUserProvider)?.uid != uid) return null;

  final perfil = profile?['perfil']?.toString() ?? ref.read(currentUserPerfilProvider);
  final canSeeAll = isAdminApproverUser(user) ||
      isPerfilAdministrador(perfil) ||
      isPerfilSupervisorInstitucional(perfil) ||
      ref.read(currentUserIsAdminProvider).valueOrNull == true;
  final assignedProjects = (profile?['proyectos'] as List?)
          ?.whereType<String>()
          .map((project) => project.trim().toUpperCase())
          .where((project) => project.isNotEmpty)
          .toSet() ??
      ref.read(currentUserAssignedProjectsProvider).toSet();

  final rows = await ref.read(archivosGeoJsonRepositoryProvider).getArchivos();
  if (ref.read(currentUserProvider)?.uid != uid) return null;

  final visibles = <ImportedFile>[];
  for (final row in rows) {
    final ImportedFile file;
    try {
      file = ImportedFile.fromBD(row);
    } catch (_) {
      continue;
    }
    final owned = file.createdByUid == null || file.createdByUid == uid;
    if (!canSeeAll && !owned) {
      if (assignedProjects.isEmpty) continue;
      final project = (file.proyecto ??
              GeoJsonMapper.detectarProyectoDesdeFeatures(file.features))
          ?.trim()
          .toUpperCase();
      if (project == null || !assignedProjects.contains(project)) continue;
    }
    visibles.add(file);
  }
  return visibles;
}

/// Nombre del archivo normalizado (sin acentos, solo A-Z0-9) para
/// detectar capas por nombre ("ENVOLVENTE", "PKS").
String nombreArchivoNormalizado(ImportedFile file) => import_norm
    .stripAccents(file.name.toUpperCase())
    .replaceAll(RegExp(r'[^A-Z0-9]'), '');

Map<String, dynamic>? _geometriaComoMapa(dynamic geometry) {
  if (geometry is Map<String, dynamic>) return geometry;
  if (geometry is Map) return Map<String, dynamic>.from(geometry);
  return null;
}

/// Un archivo guardado es de puntos PKS si todas sus geometrías son
/// puntos y su nombre contiene "PKS" o alguna propiedad es un campo de PK.
bool esArchivoPksGuardado(ImportedFile file) {
  if (file.features.isEmpty) return false;
  final geometries = file.features
      .map((feature) => _geometriaComoMapa(feature['geometry'])?['type']?.toString().toUpperCase())
      .whereType<String>()
      .toList(growable: false);
  if (geometries.isEmpty ||
      geometries.any((type) => type != 'POINT' && type != 'MULTIPOINT')) {
    return false;
  }
  if (nombreArchivoNormalizado(file).contains('PKS')) return true;
  const camposPk = {
    'pkslabel', 'pks', 'pksnum', 'pksnumero', 'numeropk', 'numeropks',
    'cadenamiento', 'cadenamien', 'pk',
  };
  return file.features.any((feature) {
    final rawProperties = feature['properties'];
    if (rawProperties is! Map) return false;
    return rawProperties.keys.any((key) => camposPk.contains(import_norm
        .stripAccents(key.toString().toLowerCase())
        .replaceAll(RegExp(r'[^a-z0-9]'), '')));
  });
}

List<Map<String, dynamic>> etiquetarFeaturesPks(
  List<Map<String, dynamic>> features,
) =>
    features.map((feature) {
      final rawProperties = feature['properties'];
      final properties = rawProperties is Map
          ? Map<String, dynamic>.from(rawProperties)
          : <String, dynamic>{};
      return <String, dynamic>{
        ...feature,
        '__import_kind': 'pks',
        'properties': properties,
      };
    }).toList(growable: false);

/// Carga los puntos PKS guardados en [pksPointFeaturesProvider] si aún no
/// hay ninguno en memoria. Lo usan las vistas que muestran PKS sin pasar
/// antes por el Mapa (p.ej. Composiciones tras recargar la página).
Future<void> asegurarPksCargados(WidgetRef ref) async {
  if (ref.read(pksPointFeaturesProvider).isNotEmpty) return;
  try {
    final archivos = await cargarArchivosGuardadosVisibles(ref);
    if (archivos == null) return;
    final pks = [
      for (final file in archivos)
        if (esArchivoPksGuardado(file)) ...etiquetarFeaturesPks(file.features),
    ];
    if (pks.isNotEmpty && ref.read(pksPointFeaturesProvider).isEmpty) {
      ref.read(pksPointFeaturesProvider.notifier).state = pks;
    }
  } catch (_) {
    // Best-effort: si falla, el Mapa volverá a intentarlo al abrirse.
  }
}
