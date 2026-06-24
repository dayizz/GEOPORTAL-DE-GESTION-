import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/constants/app_colors.dart';
import '../../estructura/presentation/estructura_screen.dart';

// ============================================================
// Provider para obtener el usuario actual
// ============================================================

/// Provider para obtener el primer usuario (simulaciรณn de usuario logueado)
final usuarioActualProvider = Provider<Usuario?>((ref) {
  final usuarios = ref.watch(usuariosProvider);
  if (usuarios.isNotEmpty) {
    return usuarios.first;
  }
  return null;
});

// ============================================================
// PANTALLA DE PERFIL
// ============================================================

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioActualProvider);
    final nf = DateFormat('dd/MM/yyyy HH:mm');

    return AppScaffold(
      currentIndex: 4,
      title: 'Perfil',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => context.go('/login'),
          tooltip: 'Cerrar sesiรณn',
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de perfil
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      usuario?.nombre.isNotEmpty == true 
                          ? usuario!.nombre[0].toUpperCase() 
                          : '?',
                      style: const TextStyle(
                        fontSize: 40, 
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    usuario?.nombre ?? 'Usuario LDDV',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    usuario?.correo ?? 'admin@sao.mx',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Informaciรณn del usuario
            const Text(
              'Información del Usuario',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Tarjeta de informaciรณn
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Nombre
                    _buildInfoRow(
                      icon: Icons.person,
                      label: 'Nombre',
                      value: usuario?.nombre ?? 'No disponible',
                    ),
                    const Divider(height: 24),
                    
                    // Correo electronico
                    _buildInfoRow(
                      icon: Icons.email,
                      label: 'Correo electronico',
                      value: usuario?.correo ?? 'No disponible',
                    ),
                    const Divider(height: 24),
                    
                    // Tipo de perfil
                    _buildInfoRow(
                      icon: Icons.badge,
                      label: 'Tipo de perfil',
                      value: usuario?.perfil ?? 'No disponible',
                    ),
                    const Divider(height: 24),
                    
                    // Proyectos asignados
                    _buildProyectosRow(
                      icon: Icons.folder_special,
                      label: 'Proyectos asignados',
                      proyectos: usuario?.proyectos ?? [],
                    ),
                    const Divider(height: 24),
                    
                    // Ultima modificación
                    _buildInfoRow(
                      icon: Icons.update,
                      label: 'Ultima modificación',
                      value: usuario?.createdAt != null 
                          ? nf.format(usuario!.createdAt) 
                          : 'No disponible',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Configuración - Modo Oscuro
            const Text(
              'Configuración',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildModoOscuroTile(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProyectosRow({
    required IconData icon,
    required String label,
    required List<String> proyectos,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              if (proyectos.isEmpty)
                const Text(
                  'Sin proyectos asignados',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: proyectos.map((proyecto) {
                    return Chip(
                      label: Text(
                        proyecto,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getPerfilColor(String? perfil) {
    switch (perfil) {
      case 'Administrador':
        return Colors.red;
      case 'Gestor de proyecto':
        return Colors.blue;
      case 'Operativo auxiliar':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildModoOscuroTile(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: AppColors.primary,
          ),
        ),
        title: const Text(
          'Modo Oscuro',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isDarkMode ? 'Activado' : 'Desactivado',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Switch(
          value: isDarkMode,
          onChanged: (value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  value 
                      ? 'Modo oscuro activado' 
                      : 'Modo oscuro desactivado',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}