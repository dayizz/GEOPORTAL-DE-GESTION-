import '../../../../core/constants/app_colors.dart';
import 'panel_seccion_colapsable.dart';
import 'package:flutter/material.dart';
import '../../models/elemento_composicion.dart';
import '../../utils/datos_grafica.dart';
import 'color_swatch_picker.dart';

String etiquetaTipoGrafica(TipoGrafica tipo) {
  switch (tipo) {
    case TipoGrafica.kpiPanel:
      return 'KPIs (avance de proyecto)';
    case TipoGrafica.avanceDdv:
      return 'Avance DDV';
    case TipoGrafica.rangoEstatus:
      return 'Rango de estatus';
    case TipoGrafica.tipoLiberacion:
      return 'Tipo de liberación';
    case TipoGrafica.tipoPropiedad:
      return 'Avance por tipo de propiedad (ambas)';
    case TipoGrafica.tipoPropiedadPrivada:
      return 'Avance de propiedad privada';
    case TipoGrafica.tipoPropiedadSocial:
      return 'Avance de propiedad social/Dominio pleno';
    case TipoGrafica.segmentoTramoFrente:
      return 'Avance por segmento/tramo/frente';
    case TipoGrafica.cadenamiento:
      return 'Diagrama por cadenamiento';
    case TipoGrafica.avanceMensual:
      return 'Avance mensual';
    case TipoGrafica.avanceSemanal:
      return 'Avance semanal';
  }
}

const _estiloItem = TextStyle(fontSize: 12);

/// Sección "Datos de gráfica": proyecto, filtro "Ver como" (proyecto
/// completo, estaciones, cruces o un segmento/tramo/frente, igual que en
/// Balance) y tipo de gráfica. Se usa tanto al elegir una gráfica nueva
/// como en las propiedades de una ya agregada.
class SeccionDatosGrafica extends StatelessWidget {
  const SeccionDatosGrafica({
    super.key,
    required this.idCampos,
    required this.proyecto,
    required this.filtro,
    required this.tipo,
    required this.proyectos,
    required this.segmentos,
    required this.onProyectoChanged,
    required this.onFiltroChanged,
    required this.onTipoChanged,
  });

  /// Distingue los campos de distintos elementos (los `initialValue` de los
  /// dropdowns solo se leen al crearse).
  final String idCampos;
  final String? proyecto;
  final String? filtro;
  final TipoGrafica tipo;
  final List<String> proyectos;
  final List<String> segmentos;
  final ValueChanged<String> onProyectoChanged;
  final ValueChanged<String?> onFiltroChanged;
  final ValueChanged<TipoGrafica> onTipoChanged;

  @override
  Widget build(BuildContext context) {
    final opcionesFiltro = <(String?, String)>[
      (null, 'Proyecto completo'),
      (filtroGraficaEstaciones, 'Estaciones y Edificios Auxiliares'),
      (filtroGraficaCruces, 'Cruces/Transversales'),
      for (final s in segmentos) (filtroGraficaSegmento(s), s),
    ];
    // Un filtro guardado que ya no existe en el proyecto se muestra como
    // "Proyecto completo" hasta que se elija otro.
    final filtroValido = opcionesFiltro.any((o) => o.$1 == filtro) ? filtro : null;
    return PanelSeccionColapsable(
      titulo: 'Datos de gráfica',
      icono: Icons.dataset_outlined,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('grafica_proyecto_${idCampos}_$proyecto'),
          initialValue: proyecto,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Proyecto', isDense: true),
          items: [
            for (final p in {...proyectos, ?proyecto})
              DropdownMenuItem(value: p, child: Text(p, style: _estiloItem)),
          ],
          onChanged: (v) {
            if (v != null) onProyectoChanged(v);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          key: ValueKey('grafica_filtro_${idCampos}_${proyecto}_$filtroValido'),
          initialValue: filtroValido,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Segmento/tramo/frente, cruces o estaciones',
            isDense: true,
          ),
          items: [
            for (final (valor, nombre) in opcionesFiltro)
              DropdownMenuItem<String?>(
                value: valor,
                child: Text(nombre, style: _estiloItem, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onFiltroChanged,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<TipoGrafica>(
          key: ValueKey('grafica_tipo_${idCampos}_${tipo.name}'),
          initialValue: tipo,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo de gráfica', isDense: true),
          items: [
            // La opción combinada solo aparece en gráficas que ya la usaban.
            for (final t in TipoGrafica.values)
              if (t != TipoGrafica.tipoPropiedad || tipo == TipoGrafica.tipoPropiedad)
              DropdownMenuItem(value: t, child: Text(etiquetaTipoGrafica(t), style: _estiloItem)),
          ],
          onChanged: (v) {
            if (v != null) onTipoChanged(v);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Panel de propiedades para [TipoElemento.grafica]: datos a graficar y
/// fondo del elemento.
class PanelPropiedadesGrafica extends StatelessWidget {
  const PanelPropiedadesGrafica({
    super.key,
    required this.elemento,
    required this.proyectos,
    required this.segmentos,
    required this.onChanged,
    required this.onDatosChanged,
    required this.onAjustarAlContenido,
  });

  final ElementoComposicion elemento;
  final List<String> proyectos;
  final List<String> segmentos;
  final ValueChanged<ElementoComposicion Function(ElementoComposicion)> onChanged;
  // Tras cambiar proyecto/filtro/tipo, para reajustar el alto al contenido.
  final VoidCallback onDatosChanged;
  final VoidCallback onAjustarAlContenido;

  void _cambiarDatos(ElementoComposicion Function(ElementoComposicion) f) {
    onChanged(f);
    onDatosChanged();
  }

  @override
  Widget build(BuildContext context) {
    final fondoActivo = elemento.graficaFondoActivo ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionDatosGrafica(
          idCampos: elemento.id,
          proyecto: elemento.graficaProyecto,
          filtro: elemento.graficaFiltro,
          tipo: elemento.graficaTipo ?? TipoGrafica.kpiPanel,
          proyectos: proyectos,
          segmentos: segmentos,
          // Los segmentos son de cada proyecto: al cambiarlo, el filtro
          // vuelve a "Proyecto completo".
          onProyectoChanged: (v) => _cambiarDatos((e) => e.copyWith(graficaProyecto: v, clearGraficaFiltro: true)),
          onFiltroChanged: (v) => _cambiarDatos((e) => v == null
              ? e.copyWith(clearGraficaFiltro: true)
              : e.copyWith(graficaFiltro: v)),
          onTipoChanged: (v) => _cambiarDatos((e) => e.copyWith(
            graficaTipo: v,
            // Renombrar la capa solo si conservaba el nombre automático.
            nombreCapa: e.nombreCapa == ElementoComposicion.nombreGrafica(e.graficaTipo ?? TipoGrafica.kpiPanel)
                ? ElementoComposicion.nombreGrafica(v)
                : null,
          )),
        ),
        PanelSeccionColapsable(
          titulo: 'Tamaño',
          icono: Icons.aspect_ratio,
          children: [
            Text(
              'Arrastra las manijas para estirar la gráfica; el contenido se '
              'escala sin deformarse.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAjustarAlContenido,
                icon: const Icon(Icons.fit_screen, size: 18),
                label: const Text('Ajustar alto al contenido'),
              ),
            ),
          ],
        ),
        PanelSeccionColapsable(
          titulo: 'Fondo',
          icono: Icons.format_color_fill,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Mostrar fondo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: fondoActivo,
                  onChanged: (v) => onChanged((e) => e.copyWith(graficaFondoActivo: v)),
                ),
              ],
            ),
            if (fondoActivo)
              ColorSwatchPicker(
                label: 'Color de fondo',
                colorHex: elemento.graficaFondoHex ?? '#FFFFFF',
                onChanged: (v) {
                  if (v != null) onChanged((e) => e.copyWith(graficaFondoHex: v));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ],
    );
  }
}
