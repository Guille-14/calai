import 'package:flutter/material.dart';

/// Enum que representa los rangos disponibles en Heavy Local.
enum RangoMuscular {
  hierro,
  bronce,
  plata,
  oro,
  platino,
  esmeralda,
  diamante,
  maestro,
  campeon,
  simetrico,
}

/// Extensiones para obtener información legible y colores del rango.
extension RangoMuscularExtension on RangoMuscular {
  String get nombre {
    switch (this) {
      case RangoMuscular.hierro:
        return 'Hierro';
      case RangoMuscular.bronce:
        return 'Bronce';
      case RangoMuscular.plata:
        return 'Plata';
      case RangoMuscular.oro:
        return 'Oro';
      case RangoMuscular.platino:
        return 'Platino';
      case RangoMuscular.esmeralda:
        return 'Esmeralda';
      case RangoMuscular.diamante:
        return 'Diamante';
      case RangoMuscular.maestro:
        return 'Maestro';
      case RangoMuscular.campeon:
        return 'Campeón';
      case RangoMuscular.simetrico:
        return 'Simétrico';
    }
  }

  Color get color {
    switch (this) {
      case RangoMuscular.hierro:
        return const Color(0xFF7F7F7F);
      case RangoMuscular.bronce:
        return const Color(0xFFCD7F32);
      case RangoMuscular.plata:
        return const Color(0xFFC0C0C0);
      case RangoMuscular.oro:
        return const Color(0xFFFFD700);
      case RangoMuscular.platino:
        return const Color(0xFFE5E4E2);
      case RangoMuscular.esmeralda:
        return const Color(0xFF50C878);
      case RangoMuscular.diamante:
        return const Color(0xFFB9F2FF);
      case RangoMuscular.maestro:
        return const Color(0xFF8A2BE2);
      case RangoMuscular.campeon:
        return const Color(0xFFFF4500);
      case RangoMuscular.simetrico:
        return const Color(0xFF00BCD4);
    }
  }
}

/// Modelo que guarda el progreso de fuerza para un grupo muscular.
class RangoPorMusculo {
  final String grupoMuscular;
  final double volumenUltimoMes;
  final RangoMuscular rangoActual;
  final double volumenSiguienteRango;

  RangoPorMusculo({
    required this.grupoMuscular,
    required this.volumenUltimoMes,
    required this.rangoActual,
    required this.volumenSiguienteRango,
  });

  /// Calcula el rango según el volumen acumulado en el último mes.
  factory RangoPorMusculo.desdeVolumen({
    required String grupoMuscular,
    required double volumenUltimoMes,
  }) {
    final rango = RangoSistema.obtenerRangoDesdeVolumen(volumenUltimoMes);
    final siguiente = RangoSistema.volumenParaSiguienteRango(volumenUltimoMes);
    return RangoPorMusculo(
      grupoMuscular: grupoMuscular,
      volumenUltimoMes: volumenUltimoMes,
      rangoActual: rango,
      volumenSiguienteRango: siguiente,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'grupoMuscular': grupoMuscular,
      'volumenUltimoMes': volumenUltimoMes,
      'rangoActual': rangoActual.index,
      'volumenSiguienteRango': volumenSiguienteRango,
    };
  }

  factory RangoPorMusculo.fromJson(Map<String, dynamic> json) {
    return RangoPorMusculo(
      grupoMuscular: json['grupoMuscular'] as String,
      volumenUltimoMes: (json['volumenUltimoMes'] as num).toDouble(),
      rangoActual: RangoMuscular.values[json['rangoActual'] as int],
      volumenSiguienteRango:
          (json['volumenSiguienteRango'] as num).toDouble(),
    );
  }
}

/// Lógica central de rangos basada en volumen de fuerza acumulado.
class RangoSistema {
  RangoSistema._();

  static final Map<RangoMuscular, double> _umbrales = {
    RangoMuscular.hierro: 0,
    RangoMuscular.bronce: 5000,
    RangoMuscular.plata: 12000,
    RangoMuscular.oro: 20000,
    RangoMuscular.platino: 32000,
    RangoMuscular.esmeralda: 47000,
    RangoMuscular.diamante: 65000,
    RangoMuscular.maestro: 86000,
    RangoMuscular.campeon: 110000,
    RangoMuscular.simetrico: 140000,
  };

  /// Devuelve el rango correspondiente al volumen acumulado.
  static RangoMuscular obtenerRangoDesdeVolumen(double volumen) {
    RangoMuscular rangoSeleccionado = RangoMuscular.hierro;

    for (final entry in _umbrales.entries) {
      if (volumen >= entry.value) {
        rangoSeleccionado = entry.key;
      } else {
        break;
      }
    }

    return rangoSeleccionado;
  }

  /// Devuelve el volumen mínimo necesario para alcanzar el siguiente rango.
  static double volumenParaSiguienteRango(double volumenActual) {
    final indices = RangoMuscular.values;
    final rangoActual = obtenerRangoDesdeVolumen(volumenActual);
    final indiceActual = indices.indexOf(rangoActual);

    if (indiceActual == indices.length - 1) {
      return volumenActual;
    }

    final siguienteRango = indices[indiceActual + 1];
    return _umbrales[siguienteRango]!;
  }

  /// Devuelve el porcentaje de progreso hacia el siguiente rango.
  static double progresoHaciaSiguienteRango(double volumenActual) {
    final rangoActual = obtenerRangoDesdeVolumen(volumenActual);
    final umbralActual = _umbrales[rangoActual]!;
    final siguienteVolumen = volumenParaSiguienteRango(volumenActual);
    if (siguienteVolumen == umbralActual) {
      return 1.0;
    }
    return ((volumenActual - umbralActual) /
            (siguienteVolumen - umbralActual))
        .clamp(0.0, 1.0);
  }
}
