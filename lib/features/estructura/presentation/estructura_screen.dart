import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

// ============================================================
// MODELOS
// ============================================================

/// Modelo para usuarios del sistema
class Usuario {
  final String id;
  final String nombre;
  final String correo;
  final String perfil; // Administrador, Gestor de proyecto, Operativo auxiliar
  final List<String> proyectos;
  final DateTime createdAt;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.perfil,
    required this.proyectos,
    required this.createdAt,
  });

  Usuario copyWith({
    String? id,
    String? nombre,
    String? correo,
    String? perfil,
    List<String>? proyectos,
    DateTime? createdAt,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      perfil: perfil ?? this.perfil,
      proyectos: proyectos ?? this.proyectos,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Usuario.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtRaw = data['created_at'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.now();

    return Usuario(
      id: doc.id,
      nombre: (data['nombre'] as String?)?.trim().isNotEmpty == true
          ? (data['nombre'] as String).trim()
          : 'Usuario',
      correo: (data['correo'] as String?)?.trim() ?? '',
      perfil: (data['perfil'] as String?)?.trim().isNotEmpty == true
          ? (data['perfil'] as String).trim()
          : 'Operativo auxiliar',
      proyectos: (data['proyectos'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      createdAt: createdAt,
    );
  }
}

/// Modelo para proyectos del sistema
class ProyectoItem {
  final String id;
  final String nombre;
  final String descripcion;
  final bool activo;
  final DateTime createdAt;

  const ProyectoItem({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.activo,
    required this.createdAt,
  });

  ProyectoItem copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    bool? activo,
    DateTime? createdAt,
  }) {
    return ProyectoItem(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ============================================================
// PROVIDERS
// ============================================================

final usuariosCollectionProvider =
    Provider<CollectionReference<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('usuarios_sistema');
});

/// Stream de usuarios persistidos en Firestore
final usuariosProvider = StreamProvider<List<Usuario>>((ref) {
  final collection = ref.watch(usuariosCollectionProvider);
  return collection
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map(Usuario.fromFirestore).toList(growable: false));
});

/// Provider para proyectos
final proyectosItemsProvider = StateNotifierProvider<ProyectosItemsNotifier, List<ProyectoItem>>((ref) {
  return ProyectosItemsNotifier();
});

class ProyectosItemsNotifier extends StateNotifier<List<ProyectoItem>> {
  ProyectosItemsNotifier() : super(_proyectosIniciales);

  static final _proyectosIniciales = [
    ProyectoItem(
      id: const Uuid().v4(),
      nombre: 'TQI',
      descripcion: 'Tren Querétaro - Irapuato',
      activo: true,
      createdAt: DateTime.now(),
    ),
    ProyectoItem(
      id: const Uuid().v4(),
      nombre: 'TSNL',
      descripcion: 'Tren Saltillo - Nuevo Laredo',
      activo: true,
      createdAt: DateTime.now(),
    ),
    ProyectoItem(
      id: const Uuid().v4(),
      nombre: 'TAP',
      descripcion: 'Tren AIFA - Pachuca',
      activo: true,
      createdAt: DateTime.now(),
    ),
    ProyectoItem(
      id: const Uuid().v4(),
      nombre: 'TMQ',
      descripcion: 'Tren México - Querétaro',
      activo: false,
      createdAt: DateTime.now(),
    ),
  ];

  void agregarProyecto(ProyectoItem proyecto) {
    state = [...state, proyecto];
  }

  void actualizarProyecto(ProyectoItem proyecto) {
    state = state.map((p) => p.id == proyecto.id ? proyecto : p).toList();
  }

  void eliminarProyecto(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void togglearActivo(String id) {
    state = state.map((p) {
      if (p.id == id) {
        return p.copyWith(activo: !p.activo);
      }
      return p;
    }).toList();
  }
}

// ============================================================
// PANTALLA PRINCIPAL
// ============================================================

class EstructuraScreen extends ConsumerStatefulWidget {
  const EstructuraScreen({super.key});

  @override
  ConsumerState<EstructuraScreen> createState() => _EstructuraScreenState();
}

class _EstructuraScreenState extends ConsumerState<EstructuraScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 6,
      title: 'Estructura',
      child: Column(
        children: [
          Container(
            color: AppColors.primary,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'Cuentas de Usuario', icon: Icon(Icons.people)),
                Tab(text: 'Proyectos', icon: Icon(Icons.folder_special)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _CuentasUsuarioTab(),
                _ProyectosTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SECCIÓN 1: CUENTAS DE USUARIO
// ============================================================

class _CuentasUsuarioTab extends ConsumerStatefulWidget {
  const _CuentasUsuarioTab();

  @override
  ConsumerState<_CuentasUsuarioTab> createState() => _CuentasUsuarioTabState();
}

class _CuentasUsuarioTabState extends ConsumerState<_CuentasUsuarioTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedRole = 'Todos';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesFilters(Usuario usuario) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final byRole = _selectedRole == 'Todos' || usuario.perfil == _selectedRole;
    if (q.isEmpty) return byRole;

    final matchesText = usuario.nombre.toLowerCase().contains(q) ||
        usuario.correo.toLowerCase().contains(q) ||
        usuario.proyectos.any((p) => p.toLowerCase().contains(q));
    return byRole && matchesText;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(ensureCurrentUserProfileProvider);
    final usuariosAsync = ref.watch(usuariosProvider);
    final authUser = ref.watch(currentUserProvider) ?? FirebaseAuth.instance.currentUser;
    final currentIsAdminAsync = ref.watch(currentUserIsAdminProvider);
    final currentPerfil = ref.watch(currentUserPerfilProvider);
    final isAdmin = currentIsAdminAsync.valueOrNull == true ||
        isPerfilAdministrador(currentPerfil) ||
        isAdminApproverUser(authUser);
    final canViewUsers = isAdmin || canViewEstructura(currentPerfil);

    if (currentIsAdminAsync.isLoading && !canViewUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!canViewUsers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tu perfil no tiene acceso a Estructura.\n\n'
            'Administrador: gestion completa\n'
            'Gestor de proyecto: sin acceso\n'
            'Operativo auxiliar: sin acceso',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildPermissionsCard(currentPerfil),
          ),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildAdminApprovalCard(context, ref),
            ),
          Expanded(
            child: usuariosAsync.when(
              data: (usuarios) {
                final filtrados = usuarios.where(_matchesFilters).toList();
                if (usuarios.isEmpty) {
                  return _buildEmptyState(context, ref, isAdmin: isAdmin);
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildResumenUsuarios(usuarios),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildFiltros(),
                    ),
                    Expanded(
                      child: filtrados.isEmpty
                          ? const Center(child: Text('No hay usuarios con ese filtro'))
                          : _buildUsuariosList(context, ref, filtrados, isAdmin: isAdmin),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No fue posible cargar usuarios: $error',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAgregarUsuarioDialog(context, ref),
              icon: const Icon(Icons.person_add),
              label: const Text('Nuevo Usuario'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildResumenUsuarios(List<Usuario> usuarios) {
    final admins = usuarios.where((u) => u.perfil == perfilAdministrador).length;
    final gestores = usuarios.where((u) => u.perfil == perfilGestorProyecto).length;
    final operativos = usuarios.where((u) => u.perfil == perfilOperativoAuxiliar).length;

    Widget metric(String label, int value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        metric('Total', usuarios.length, AppColors.primary),
        const SizedBox(width: 8),
        metric('Admins', admins, Colors.red),
        const SizedBox(width: 8),
        metric('Gestores', gestores, Colors.blue),
        const SizedBox(width: 8),
        metric('Operativos', operativos, Colors.green),
      ],
    );
  }

  Widget _buildFiltros() {
    return Column(
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre, correo o proyecto',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Todos', perfilAdministrador, perfilGestorProyecto, perfilOperativoAuxiliar]
              .map(
                (rol) => ChoiceChip(
                  label: Text(rol),
                  selected: _selectedRole == rol,
                  onSelected: (_) => setState(() => _selectedRole = rol),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPermissionsCard(String perfil) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Perfil activo: $perfil. '
                'Administrador: gestiona usuarios y proyectos '
                'Gestor: gestiona proyectos y sube informacion '
                'Operativo: consulta informacion y actualiza datos',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminApprovalCard(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aprobacion de Usuarios',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Genera un codigo de aprobacion para habilitar el registro de un nuevo usuario. '
              'Cada codigo se puede usar una sola vez y vence 1 minuto despues de generarse.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _generarCodigoAprobacion(context, ref),
              icon: const Icon(Icons.password_rounded),
              label: const Text('Generar codigo de aprobacion'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarCodigoAprobacion(BuildContext context, WidgetRef ref) async {
    try {
      final code = await ref.read(authRepositoryProvider).generateApprovalCode();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Codigo generado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vence en 1 minuto. Comparte y usa el codigo de inmediato.',
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Codigo copiado al portapapeles.')),
                    );
                  }
                },
                child: const Text('Copiar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, {required bool isAdmin}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay usuarios registrados',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showAgregarUsuarioDialog(context, ref),
              icon: const Icon(Icons.person_add),
              label: const Text('Agregar Usuario'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsuariosList(
    BuildContext context,
    WidgetRef ref,
    List<Usuario> usuarios, {
    required bool isAdmin,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: usuarios.length,
      itemBuilder: (context, index) {
        final usuario = usuarios[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              usuario.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.email, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        usuario.correo,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildPerfilChip(usuario.perfil),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: usuario.proyectos
                      .map((proyecto) => Chip(
                            label: Text(
                              proyecto,
                              style: const TextStyle(fontSize: 10),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                          ))
                      .toList(),
                ),
              ],
            ),
            trailing: isAdmin
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'editar') {
                        _showEditarUsuarioDialog(context, ref, usuario);
                      } else if (value == 'eliminar') {
                        _showEliminarUsuarioDialog(context, ref, usuario);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'eliminar',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('Eliminar', style: TextStyle(color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildPerfilChip(String perfil) {
    Color color;
    switch (perfil) {
      case perfilAdministrador:
        color = Colors.red;
        break;
      case perfilGestorProyecto:
        color = Colors.blue;
        break;
      case perfilOperativoAuxiliar:
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        perfil,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<bool> _saveUsuario(BuildContext context, WidgetRef ref, Usuario usuario) async {
    final collection = ref.read(usuariosCollectionProvider);
    try {
      await collection.doc(usuario.id).set({
        'uid': usuario.id,
        'nombre': usuario.nombre.trim(),
        'correo': usuario.correo.trim().toLowerCase(),
        'perfil': usuario.perfil,
        'proyectos': usuario.proyectos,
        'created_at': Timestamp.fromDate(usuario.createdAt),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario guardado')),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No fue posible guardar el usuario: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _deleteUsuario(BuildContext context, WidgetRef ref, String id) async {
    final collection = ref.read(usuariosCollectionProvider);
    try {
      await collection.doc(id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario eliminado')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No fue posible eliminar el usuario: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showAgregarUsuarioDialog(BuildContext context, WidgetRef ref) {
    final nombreCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    String perfilSeleccionado = perfilOperativoAuxiliar;
    List<String> proyectosSeleccionados = [];

    final proyectosItems = ref.read(proyectosItemsProvider);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo Usuario'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: correoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Perfil',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      perfilAdministrador,
                      perfilGestorProyecto,
                      perfilOperativoAuxiliar,
                    ].map((perfil) {
                      return ChoiceChip(
                        label: Text(perfil),
                        selected: perfilSeleccionado == perfil,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => perfilSeleccionado = perfil);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Proyectos asignados',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: proyectosItems.map((proyecto) {
                      final selected = proyectosSeleccionados.contains(proyecto.nombre);
                      return FilterChip(
                        label: Text(proyecto.nombre),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              proyectosSeleccionados.add(proyecto.nombre);
                            } else {
                              proyectosSeleccionados.remove(proyecto.nombre);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreCtrl.text.isNotEmpty && correoCtrl.text.isNotEmpty) {
                  final usuario = Usuario(
                    id: const Uuid().v4(),
                    nombre: nombreCtrl.text,
                    correo: correoCtrl.text,
                    perfil: perfilSeleccionado,
                    proyectos: proyectosSeleccionados,
                    createdAt: DateTime.now(),
                  );
                  final ok = await _saveUsuario(context, ref, usuario);
                  if (!context.mounted || !ok) return;
                  Navigator.pop(context);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditarUsuarioDialog(BuildContext context, WidgetRef ref, Usuario usuario) {
    final nombreCtrl = TextEditingController(text: usuario.nombre);
    final correoCtrl = TextEditingController(text: usuario.correo);
    String perfilSeleccionado = usuario.perfil;
    List<String> proyectosSeleccionados = List.from(usuario.proyectos);

    final proyectosItems = ref.read(proyectosItemsProvider);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Usuario'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: correoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Perfil',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      perfilAdministrador,
                      perfilGestorProyecto,
                      perfilOperativoAuxiliar,
                    ].map((perfil) {
                      return ChoiceChip(
                        label: Text(perfil),
                        selected: perfilSeleccionado == perfil,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => perfilSeleccionado = perfil);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Proyectos asignados',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: proyectosItems.map((proyecto) {
                      final selected = proyectosSeleccionados.contains(proyecto.nombre);
                      return FilterChip(
                        label: Text(proyecto.nombre),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              proyectosSeleccionados.add(proyecto.nombre);
                            } else {
                              proyectosSeleccionados.remove(proyecto.nombre);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreCtrl.text.isNotEmpty && correoCtrl.text.isNotEmpty) {
                  final usuarioActualizado = usuario.copyWith(
                    nombre: nombreCtrl.text,
                    correo: correoCtrl.text,
                    perfil: perfilSeleccionado,
                    proyectos: proyectosSeleccionados,
                  );
                  final ok = await _saveUsuario(context, ref, usuarioActualizado);
                  if (!context.mounted || !ok) return;
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEliminarUsuarioDialog(BuildContext context, WidgetRef ref, Usuario usuario) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text('¿Estás seguro de que deseas eliminar al usuario "${usuario.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deleteUsuario(context, ref, usuario.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SECCIÓN 2: PROYECTOS
// ============================================================

class _ProyectosTab extends ConsumerWidget {
  const _ProyectosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectos = ref.watch(proyectosItemsProvider);
    final currentIsAdminAsync = ref.watch(currentUserIsAdminProvider);
    final perfil = ref.watch(currentUserPerfilProvider);
    final canManageProjects = currentIsAdminAsync.valueOrNull == true || isPerfilAdministrador(perfil) || isPerfilGestor(perfil);

    return Scaffold(
      body: proyectos.isEmpty
          ? _buildEmptyState(context, ref, canManageProjects: canManageProjects)
          : _buildProyectosList(context, ref, proyectos, canManageProjects: canManageProjects),
      floatingActionButton: canManageProjects
          ? FloatingActionButton.extended(
              onPressed: () => _showAgregarProyectoDialog(context, ref),
              icon: const Icon(Icons.add_business),
              label: const Text('Nuevo Proyecto'),
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, {required bool canManageProjects}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay proyectos registrados',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          if (canManageProjects) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showAgregarProyectoDialog(context, ref),
              icon: const Icon(Icons.add_business),
              label: const Text('Agregar Proyecto'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProyectosList(
    BuildContext context,
    WidgetRef ref,
    List<ProyectoItem> proyectos, {
    required bool canManageProjects,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: proyectos.length,
      itemBuilder: (context, index) {
        final proyecto = proyectos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: proyecto.activo
                  ? AppColors.secondary.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              child: Icon(
                Icons.folder_special,
                color: proyecto.activo ? AppColors.secondary : Colors.grey,
              ),
            ),
            title: Row(
              children: [
                Text(
                  proyecto.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: proyecto.activo
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    proyecto.activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: proyecto.activo ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  proyecto.descripcion,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: canManageProjects
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'editar') {
                        _showEditarProyectoDialog(context, ref, proyecto);
                      } else if (value == 'eliminar') {
                        _showEliminarProyectoDialog(context, ref, proyecto);
                      } else if (value == 'toggle') {
                        ref.read(proyectosItemsProvider.notifier).togglearActivo(proyecto.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              proyecto.activo ? Icons.pause : Icons.play_arrow,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(proyecto.activo ? 'Desactivar' : 'Activar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'eliminar',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('Eliminar', style: TextStyle(color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showAgregarProyectoDialog(BuildContext context, WidgetRef ref) {
    final nombreCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Proyecto'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del proyecto',
                  prefixIcon: Icon(Icons.folder_special),
                  border: OutlineInputBorder(),
                  hintText: 'Ej: TQI, TSNL, TAP, TQM',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descripcionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.isNotEmpty) {
                final proyecto = ProyectoItem(
                  id: const Uuid().v4(),
                  nombre: nombreCtrl.text.toUpperCase(),
                  descripcion: descripcionCtrl.text,
                  activo: true,
                  createdAt: DateTime.now(),
                );
                ref.read(proyectosItemsProvider.notifier).agregarProyecto(proyecto);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Proyecto agregado')),
                );
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showEditarProyectoDialog(BuildContext context, WidgetRef ref, ProyectoItem proyecto) {
    final nombreCtrl = TextEditingController(text: proyecto.nombre);
    final descripcionCtrl = TextEditingController(text: proyecto.descripcion);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Proyecto'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del proyecto',
                  prefixIcon: Icon(Icons.folder_special),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descripcionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.isNotEmpty) {
                final proyectoActualizado = proyecto.copyWith(
                  nombre: nombreCtrl.text.toUpperCase(),
                  descripcion: descripcionCtrl.text,
                );
                ref.read(proyectosItemsProvider.notifier).actualizarProyecto(proyectoActualizado);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Proyecto actualizado')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEliminarProyectoDialog(BuildContext context, WidgetRef ref, ProyectoItem proyecto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Proyecto'),
        content: Text('¿Estás seguro de que deseas eliminar el proyecto "${proyecto.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(proyectosItemsProvider.notifier).eliminarProyecto(proyecto.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proyecto eliminado')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}