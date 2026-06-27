import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/constants/app_colors.dart';

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
// PROVIDERS (Estado en memoria)
// ============================================================

/// Provider para usuarios
final usuariosProvider = StateNotifierProvider<UsuariosNotifier, List<Usuario>>((ref) {
  return UsuariosNotifier();
});

class UsuariosNotifier extends StateNotifier<List<Usuario>> {
  UsuariosNotifier() : super(_usuariosIniciales);

  static final _usuariosIniciales = [
    Usuario(
      id: const Uuid().v4(),
      nombre: 'Juan Pérez García',
      correo: 'juan.perez@lddv.com',
      perfil: 'Administrador',
      proyectos: ['TQI', 'TSNL'],
      createdAt: DateTime.now(),
    ),
    Usuario(
      id: const Uuid().v4(),
      nombre: 'María Rodríguez',
      correo: 'maria.rodriguez@lddv.com',
      perfil: 'Gestor de proyecto',
      proyectos: ['TAP'],
      createdAt: DateTime.now(),
    ),
    Usuario(
      id: const Uuid().v4(),
      nombre: 'Carlos López',
      correo: 'carlos.lopez@lddv.com',
      perfil: 'Operativo auxiliar',
      proyectos: ['TQM', 'TQI'],
      createdAt: DateTime.now(),
    ),
  ];

  void agregarUsuario(Usuario usuario) {
    state = [...state, usuario];
  }

  void actualizarUsuario(Usuario usuario) {
    state = state.map((u) => u.id == usuario.id ? usuario : u).toList();
  }

  void eliminarUsuario(String id) {
    state = state.where((u) => u.id != id).toList();
  }
}

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
      currentIndex: 5,
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

class _CuentasUsuarioTab extends ConsumerWidget {
  const _CuentasUsuarioTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarios = ref.watch(usuariosProvider);

    return Scaffold(
      body: usuarios.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildUsuariosList(context, ref, usuarios),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAgregarUsuarioDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Usuario'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
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
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showAgregarUsuarioDialog(context, ref),
            icon: const Icon(Icons.person_add),
            label: const Text('Agregar Usuario'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsuariosList(BuildContext context, WidgetRef ref, List<Usuario> usuarios) {
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
            trailing: PopupMenuButton<String>(
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerfilChip(String perfil) {
    Color color;
    switch (perfil) {
      case 'Administrador':
        color = Colors.red;
        break;
      case 'Gestor de proyecto':
        color = Colors.blue;
        break;
      case 'Operativo auxiliar':
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

  void _showAgregarUsuarioDialog(BuildContext context, WidgetRef ref) {
    final nombreCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    String perfilSeleccionado = 'Operativo auxiliar';
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
                      'Administrador',
                      'Gestor de proyecto',
                      'Operativo auxiliar',
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
              onPressed: () {
                if (nombreCtrl.text.isNotEmpty && correoCtrl.text.isNotEmpty) {
                  final usuario = Usuario(
                    id: const Uuid().v4(),
                    nombre: nombreCtrl.text,
                    correo: correoCtrl.text,
                    perfil: perfilSeleccionado,
                    proyectos: proyectosSeleccionados,
                    createdAt: DateTime.now(),
                  );
                  ref.read(usuariosProvider.notifier).agregarUsuario(usuario);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Usuario agregado')),
                  );
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
                      'Administrador',
                      'Gestor de proyecto',
                      'Operativo auxiliar',
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
              onPressed: () {
                if (nombreCtrl.text.isNotEmpty && correoCtrl.text.isNotEmpty) {
                  final usuarioActualizado = usuario.copyWith(
                    nombre: nombreCtrl.text,
                    correo: correoCtrl.text,
                    perfil: perfilSeleccionado,
                    proyectos: proyectosSeleccionados,
                  );
                  ref.read(usuariosProvider.notifier).actualizarUsuario(usuarioActualizado);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Usuario actualizado')),
                  );
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
            onPressed: () {
              ref.read(usuariosProvider.notifier).eliminarUsuario(usuario.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Usuario eliminado')),
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

// ============================================================
// SECCIÓN 2: PROYECTOS
// ============================================================

class _ProyectosTab extends ConsumerWidget {
  const _ProyectosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectos = ref.watch(proyectosItemsProvider);

    return Scaffold(
      body: proyectos.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildProyectosList(context, ref, proyectos),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAgregarProyectoDialog(context, ref),
        icon: const Icon(Icons.add_business),
        label: const Text('Nuevo Proyecto'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
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
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showAgregarProyectoDialog(context, ref),
            icon: const Icon(Icons.add_business),
            label: const Text('Agregar Proyecto'),
          ),
        ],
      ),
    );
  }

  Widget _buildProyectosList(BuildContext context, WidgetRef ref, List<ProyectoItem> proyectos) {
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
            trailing: PopupMenuButton<String>(
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
            ),
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