import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1B6CA8);
  static const Color primaryDark = Color(0xFF0D4F7C);
  static const Color primaryLight = Color(0xFF3A8FCC);
  static const Color secondary = Color(0xFF27AE60);
  static const Color secondaryDark = Color(0xFF1E8449);
  static const Color accent = Color(0xFFF39C12);
  static const Color danger = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF1C40F);
  static const Color info = Color(0xFF3498DB);

  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEFF2F7);
  static const Color border = Color(0xFFDDE1E9);

  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8D);
  static const Color textLight = Color(0xFFB0BAC9);

  static const Color mapBackground = Color(0xFFE8F0F7);

  // Usos de suelo
  static const Color usoHabitacional = Color(0xFF3498DB);
  static const Color usoComercial = Color(0xFFF39C12);
  static const Color usoIndustrial = Color(0xFFE74C3C);
  static const Color usoAgricola = Color(0xFF27AE60);
  static const Color usoMixto = Color(0xFF9B59B6);
  static const Color usoEquipamiento = Color(0xFF1ABC9C);
  static const Color usoOtro = Color(0xFF95A5A6);

  static Color usoSueloColor(String uso) {
    switch (uso.toLowerCase()) {
      case 'habitacional':
        return usoHabitacional;
      case 'comercial':
        return usoComercial;
      case 'industrial':
        return usoIndustrial;
      case 'agrícola':
      case 'agricola':
        return usoAgricola;
      case 'mixto':
        return usoMixto;
      case 'equipamiento':
        return usoEquipamiento;
      default:
        return usoOtro;
    }
  }

  // Colores para tipos de propiedad LDDV
  // Simbologia oficial: usada tanto en Mapa (visualizar poligonos por
  // "tipo de propiedad") como en Gestion (tabla, chips, reportes).

  static const Color tipoPrivada = Color(0xFFFB8C00);        // naranja
  static const Color tipoSocial = Color(0xFFB39DDB);         // morado claro
  static const Color tipoDominioPleno = Color(0xFF4DB6AC);   // verde agua
  static const Color tipoGubernamental = Color(0xFF7B1E3D);  // rojo vino
  static const Color tipoMunicipal = Color(0xFFF48FB1);      // rosa claro
  static const Color tipoEstatal = Color(0xFFA1887F);        // cafe claro
  static const Color tipoFederal = Color(0xFF64B5F6);        // azul claro
  static const Color tipoDesconocido = Color(0xFFBDBDBD);    // gris claro

  static Color tipoPropiedadColor(String tipo) {
    switch (tipo.toUpperCase().trim()) {
      case 'PRIVADA':
        return tipoPrivada;
      case 'SOCIAL':
        return tipoSocial;
      case 'DOMINIO PLENO':
        return tipoDominioPleno;
      case 'GUBERNAMENTAL':
        return tipoGubernamental;
      case 'MUNICIPAL':
        return tipoMunicipal;
      case 'ESTATAL':
        return tipoEstatal;
      case 'FEDERAL':
        return tipoFederal;
      case 'DESCONOCIDO':
      case 'SIN TIPO':
        return tipoDesconocido;
      default:
        return tipoDesconocido;
    }
  }

  // Colores para "Rango de estatus" (extension detallada de Estatus).
  // Se usan tanto en Gestion (columna/badge) como en Mapa (visualizar
  // poligonos por "Rango de estatus"), para que un mismo predio se pinte
  // igual en ambos lugares.

  static const Color rangoLiberado = Color(0xFF6AA84F);          // verde
  static const Color rangoLNueva = Color(0xFF00FF00);            // verde
  // Instruccion UVSR y Con ingreso comparten relleno con Posible DOT y
  // Negociacion respectivamente; se distinguen por su contorno verde
  // (ver rangoEstatusBorderColor).
  static const Color rangoInstruccionUvsr = Color(0xFFBD817E);   // relleno = Posible DOT
  static const Color rangoConIngreso = Color(0xFFFFFF00);        // relleno = Negociacion
  static const Color rangoNegociacion = Color(0xFFFFFF00);       // amarillo
  static const Color rangoPosibleDot = Color(0xFFBD817E);        // rosa/marron
  static const Color rangoNoLiberado = Color(0xFFFF0000);        // rojo
  static const Color rangoDesconocido = Color(0xFFBDBDBD);       // gris claro
  static const Color rangoContornoVerde = Color(0xFF00FF00);     // contorno distintivo

  static Color rangoEstatusColor(String? rango) {
    switch ((rango ?? '').toUpperCase().trim()) {
      case 'LIBERADO':
        return rangoLiberado;
      case 'L NUEVA':
        return rangoLNueva;
      case 'INSTRUCCION UVSR':
        return rangoInstruccionUvsr;
      case 'CON INGRESO':
        return rangoConIngreso;
      case 'NEGOCIACION':
        return rangoNegociacion;
      case 'POSIBLE DOT':
        return rangoPosibleDot;
      case 'NO LIBERADO':
        return rangoNoLiberado;
      default:
        return rangoDesconocido;
    }
  }

  /// Color de contorno para "Rango de estatus". Para la mayoria de los
  /// rangos es igual al relleno; "Instruccion UVSR" y "Con ingreso" llevan
  /// un contorno verde distintivo porque comparten relleno con otro rango
  /// (Posible DOT y Negociacion respectivamente).
  static Color rangoEstatusBorderColor(String? rango) {
    switch ((rango ?? '').toUpperCase().trim()) {
      case 'INSTRUCCION UVSR':
      case 'CON INGRESO':
        return rangoContornoVerde;
      default:
        return rangoEstatusColor(rango);
    }
  }
}