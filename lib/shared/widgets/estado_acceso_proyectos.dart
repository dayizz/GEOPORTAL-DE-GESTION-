import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/estructura/providers/proyectos_provider.dart';

/// Solo permite evaluar asignaciones después de cargar sesión y catálogo.
Widget? estadoAccesoProyectos(WidgetRef ref) {
  final auth = ref.watch(authStateProvider);
  final perfil = ref.watch(currentUserProfileProvider);
  final admin = ref.watch(currentUserIsAdminProvider);
  final proyectos = ref.watch(proyectosProvider);
  final estados = <AsyncValue<dynamic>>[auth, perfil, admin, proyectos];
  if (estados.any((estado) => estado.hasError)) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No se pudieron cargar los proyectos o los permisos de tu cuenta.'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(authStateProvider);
              ref.invalidate(currentUserProfileProvider);
              ref.invalidate(currentUserIsAdminProvider);
              ref.invalidate(proyectosProvider);
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
  if (estados.any((estado) => estado.isLoading)) {
    return const Center(child: CircularProgressIndicator());
  }
  if (proyectos.valueOrNull?.isEmpty == true) {
    return const Center(child: Text('No hay proyectos disponibles en el catálogo.'));
  }
  return null;
}
