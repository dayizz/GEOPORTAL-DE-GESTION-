import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../estructura/providers/proyectos_provider.dart';
import '../models/composicion.dart';
import '../providers/composiciones_provider.dart';

class ComposicionesListScreen extends ConsumerStatefulWidget {
  const ComposicionesListScreen({super.key});

  @override
  ConsumerState<ComposicionesListScreen> createState() => _ComposicionesListScreenState();
}

class _ComposicionesListScreenState extends ConsumerState<ComposicionesListScreen> {
  List<String> get _proyectos => ref.read(proyectosCodigosProvider);
  String _proyectoActual = '';

  @override
  Widget build(BuildContext context) {
    ref.watch(proyectosCodigosProvider);
    final canAllProjects = ref.watch(canAccessAllProjectsProvider);
    final proyectosAsignados = ref.watch(currentUserAssignedProjectsProvider);
    final proyectosDisponibles = canAllProjects
        ? _proyectos
        : _proyectos.where(proyectosAsignados.contains).toList(growable: false);

    if (proyectosDisponibles.isEmpty) {
      return AppScaffold(
        currentIndex: 7,
        title: 'Composiciones',
        child: const Center(
          child: Text('Sin proyecto asignado', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      );
    }

    final proyectoActivo =
        proyectosDisponibles.contains(_proyectoActual) ? _proyectoActual : proyectosDisponibles.first;
    if (proyectoActivo != _proyectoActual) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _proyectoActual = proyectoActivo);
      });
    }

    final composicionesAsync = ref.watch(composicionesProvider);

    return AppScaffold(
      currentIndex: 7,
      title: 'Composiciones  •  $proyectoActivo',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/composiciones/nuevo?proyecto=$proyectoActivo'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva composición'),
      ),
      child: composicionesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (todas) {
          final composiciones = todas.where((c) => c.proyecto == proyectoActivo).toList()
            ..sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Proyecto:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
                    const SizedBox(width: 10),
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDCDCDC)),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: DropdownButton<String>(
                          value: proyectoActivo,
                          isDense: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9A9A9A)),
                          style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
                          items: proyectosDisponibles.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _proyectoActual = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (composiciones.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'Sin composiciones para este proyecto todavía.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: composiciones.map((c) => _ComposicionCard(composicion: c)).toList(),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ComposicionCard extends ConsumerWidget {
  const _ComposicionCard({required this.composicion});

  final Composicion composicion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('d/MM/yyyy HH:mm', 'es_MX');
    final fecha = composicion.updatedAt ?? composicion.createdAt;

    return InkWell(
      onTap: () => context.go('/composiciones/${composicion.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.image_outlined, color: AppColors.primary, size: 22),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (value) async {
                    if (value == 'renombrar') {
                      await _renombrar(context, ref);
                    } else if (value == 'eliminar') {
                      await _confirmarEliminar(context, ref);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'renombrar', child: Text('Renombrar')),
                    PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              composicion.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${composicion.hojas.length} hoja(s)',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              fmt.format(fecha),
              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renombrar(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: composicion.nombre);
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar composición'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevoNombre == null || nuevoNombre.isEmpty) return;
    await ref.read(composicionesRepositoryProvider).renombrar(composicion.id, nuevoNombre);
  }

  Future<void> _confirmarEliminar(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar composición'),
        content: Text('¿Eliminar "${composicion.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await ref.read(composicionesRepositoryProvider).eliminar(composicion.id);
  }
}
