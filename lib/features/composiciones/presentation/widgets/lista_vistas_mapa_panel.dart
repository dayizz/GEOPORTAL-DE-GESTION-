import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../mapa/models/vista_mapa.dart';
import '../../../mapa/providers/vistas_mapa_provider.dart';

/// Lista de "vistas de mapa" guardadas (ver Mapa > icono de recuadro con
/// esquinas) para el proyecto de esta composición, con un tap para
/// insertarlas como elemento de mapa en la hoja activa (ver
/// `_insertarVistaMapa` en `composicion_editor_screen.dart`).
class ListaVistasMapaPanel extends ConsumerWidget {
  const ListaVistasMapaPanel({
    super.key,
    required this.proyecto,
    required this.onSeleccionar,
  });

  final String proyecto;
  final ValueChanged<VistaMapa> onSeleccionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vistasAsync = ref.watch(vistasMapaProvider);
    return vistasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Error: $e', style: const TextStyle(fontSize: 11, color: AppColors.danger)),
      ),
      data: (vistas) {
        final propio = vistas.where((v) => v.proyecto.trim().toUpperCase() == proyecto.trim().toUpperCase()).toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre));
        if (propio.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Sin vistas guardadas para este proyecto. Guarda una desde Mapa (icono de recuadro con esquinas).',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: propio.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final vista = propio[index];
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.crop_free, size: 18, color: AppColors.primary),
              title: Text(vista.nombre, style: const TextStyle(fontSize: 12)),
              onTap: () => onSeleccionar(vista),
            );
          },
        );
      },
    );
  }
}
