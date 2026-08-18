import 'package:flutter/material.dart';

class GuardarVistaResultado {
  const GuardarVistaResultado({required this.nombre, required this.proyecto});

  final String nombre;
  final String proyecto;
}

/// Diálogo "nombrar vista + elegir proyecto" (pasos 1.1 finales de
/// "Guardar vista de mapa"). Puramente de UI -no toca Firestore-, igual
/// que `mostrarHerramientaHojaDialog` en Composiciones: devuelve el
/// resultado y quien llama decide si crea o actualiza.
Future<GuardarVistaResultado?> mostrarGuardarVistaDialog(
  BuildContext context, {
  required List<String> proyectosDisponibles,
  String? nombreInicial,
  String? proyectoInicial,
  bool esActualizacion = false,
}) {
  final nombreCtrl = TextEditingController(text: nombreInicial ?? '');
  String? proyecto = proyectoInicial ?? (proyectosDisponibles.isNotEmpty ? proyectosDisponibles.first : null);

  return showDialog<GuardarVistaResultado>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(esActualizacion ? 'Actualizar vista de mapa' : 'Guardar vista de mapa'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nombre de la vista', isDense: true),
                  ),
                  const SizedBox(height: 16),
                  const Text('Proyecto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  proyectosDisponibles.isEmpty
                      ? const Text(
                          'No hay proyectos dados de alta en Estructura.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: proyecto,
                          isDense: true,
                          items: proyectosDisponibles
                              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (v) => setState(() => proyecto = v),
                          decoration: const InputDecoration(isDense: true),
                        ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () {
                  final nombre = nombreCtrl.text.trim();
                  final proyectoElegido = proyecto;
                  if (nombre.isEmpty || proyectoElegido == null) return;
                  Navigator.pop(ctx, GuardarVistaResultado(nombre: nombre, proyecto: proyectoElegido));
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      );
    },
  );
}
