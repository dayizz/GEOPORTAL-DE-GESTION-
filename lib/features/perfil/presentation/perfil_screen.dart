import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/constants/app_colors.dart';
import '../../estructura/presentation/estructura_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../../mapa/providers/mapa_state_cleanup.dart';

// ============================================================
// Provider para obtener el usuario actual
// ============================================================

/// Provider para obtener el primer usuario (simulaciรณn de usuario logueado)
final usuarioActualProvider = Provider<Usuario?>((ref) {
  final authUser = ref.watch(currentUserProvider) ?? FirebaseAuth.instance.currentUser;
  final usuarios = ref.watch(usuariosProvider).valueOrNull ?? const <Usuario>[];

  if (usuarios.isEmpty) {
    return null;
  }

  if (authUser == null) {
    return usuarios.first;
  }

  final email = authUser.email?.trim().toLowerCase();
  for (final usuario in usuarios) {
    if (usuario.id == authUser.uid) {
      return usuario;
    }
    if (email != null && usuario.correo.trim().toLowerCase() == email) {
      return usuario;
    }
  }

  return null;
});

// ============================================================
// PANTALLA DE PERFIL
// ============================================================

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // Ignorar errores remotos en logout y continuar limpieza local.
    }

    ref.read(localAuthSessionProvider.notifier).state = false;
    ref.read(proyectoActivoProvider.notifier).state = null;
    clearImportedMapState(ref.read);
    ref.read(gestionProyectoProvider.notifier).state = null;
    ref.read(importacionAsyncProvider.notifier).reset();

    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioActualProvider);
    final authUser = ref.watch(currentUserProvider) ?? FirebaseAuth.instance.currentUser;
    final correoMostrado =
      usuario?.correo ?? authUser?.email ?? 'No disponible';
    final nombreMostrado =
      usuario?.nombre ?? authUser?.displayName ?? 'Usuario LDDV';
    final inicial = nombreMostrado.isNotEmpty
      ? nombreMostrado[0].toUpperCase()
      : '?';
    final nf = DateFormat('dd/MM/yyyy HH:mm');

    return AppScaffold(
      currentIndex: 5,
      title: 'Perfil',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _cerrarSesion(context, ref),
          tooltip: 'Cerrar sesión',
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
                      inicial,
                      style: const TextStyle(
                        fontSize: 40, 
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nombreMostrado,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    correoMostrado,
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
                      value: nombreMostrado,
                    ),
                    const Divider(height: 24),
                    
                    // Correo electronico
                    _buildInfoRow(
                      icon: Icons.email,
                      label: 'Correo electronico',
                      value: correoMostrado,
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

            // Terminos y Politica de privacidad
            const Text(
              'Legal',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTerminosPrivacidadTile(context),
          ],
        ),
      ),
    );
  }

  static const String _terminosPrivacidadTexto =
      'TERMINOS Y CONDICIONES DE USO Y POLITICAS DE PRIVACIDAD - GEOPORTAL\n\n'
      '1. Aceptacion de los Terminos\n'
      'Al ingresar, registrarse o utilizar este Geoportal (tanto en su version Web como de Escritorio), el usuario acepta de manera expresa, automatica e incondicional todos los terminos, condiciones y politicas de privacidad aqui descritos. Si no esta de acuerdo con estas disposiciones, debera abstenerse de acceder y utilizar el sistema.\n\n'
      '2. Naturaleza del Sitio (Sin Fines de Lucro)\n'
      'Este Geoportal es una herramienta estrictamente institucional y de uso interno, desarrollada y operada sin fines de lucro. Su unico proposito es la optimizacion, visualizacion, consulta y gestion interna de la informacion cartografica, predial y documental de los proyectos asignados.\n\n'
      '3. Politica de Privacidad y Manejo de Datos de Usuario\n\n'
      '- Datos Recabados: Para el acceso y funcionamiento del Geoportal, el sistema unicamente recaba y almacena datos personales basicos identificativos: Nombre completo y Correo electronico.\n'
      '- Finalidad: Estos datos son utilizados exclusivamente para la creacion de cuentas de acceso, asignacion de roles de seguridad (Administrador, Gestor de Proyecto, Operativo Auxiliar), control de auditoria interna y personalizacion de las vistas del mapa segun el proyecto autorizado.\n'
      '- No Transferencia a Terceros: La informacion de nombre y correo electronico recolectada no se comparte, transfiere, vende ni comercializa con terceras personas, empresas u organizaciones ajenas a la institucion bajo ninguna circunstancia, garantizando la absoluta privacidad del usuario.\n\n'
      '4. Clausula de Confidencialidad de la Informacion de Trabajo\n\n'
      '- Datos de los Predios: Toda la informacion tecnica, espacial, legal y personal contenida y trabajada dentro de la plataforma (incluyendo poligonos GeoJSON, bases de datos vinculadas de Excel, estatus de gestion, propietarios y documentos PDF) tiene el caracter de estrictamente confidencial.\n'
      '- Prohibicion de Difusion: Queda estrictamente prohibido compartir, exportar, capturar, duplicar o divulgar cualquier dato o mapa de la plataforma con personas, instituciones o entidades externas.\n'
      '- Responsabilidad: El usuario es el unico responsable de resguardar sus credenciales de acceso. Cualquier fuga de informacion derivada del uso inadecuado de la cuenta o de la divulgacion voluntaria de los datos sera responsabilidad directa del usuario operativo y se sancionara de acuerdo con los reglamentos internos de la institucion.\n\n'
      '5. Reglas de Uso Correcto y Seguridad\n\n'
      '- El usuario se compromete a utilizar las herramientas del mapa y las tablas de datos unicamente para los fines laborales asignados.\n'
      '- Se prohibe cualquier intento de vulnerar las medidas de seguridad perimetral de la base de datos o eludir las restricciones de visibilidad por proyecto (Row Level Security - RLS).';

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
      case 'Supervisor Institucional':
        return Colors.orange;
      case 'Operativo auxiliar':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTerminosPrivacidadTile(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description_outlined, color: AppColors.primary),
        ),
        title: const Text(
          'Condiciones y Politica de privacidad',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Consultar terminos y politicas de uso de la plataforma',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showTerminosPrivacidadDialog(context),
      ),
    );
  }

  void _showTerminosPrivacidadDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Condiciones y Politica de privacidad'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Text(
                _terminosPrivacidadTexto,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}