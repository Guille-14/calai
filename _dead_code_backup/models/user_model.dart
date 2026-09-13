import 'rank_system.dart';

/// Modelo de perfil de usuario para Heavy Local.
class Usuario {
  final String id;
  String nombre;
  double pesoKg;
  double alturaCm;
  double porcentajeGrasa;
  DateTime fechaRegistro;
  List<RangoPorMusculo> rangosPorMusculo;

  Usuario({
    required this.id,
    required this.nombre,
    required this.pesoKg,
    required this.alturaCm,
    required this.porcentajeGrasa,
    required this.fechaRegistro,
    required this.rangosPorMusculo,
  });

  /// Crea un usuario con rangos musculares iniciales.
  factory Usuario.inicial({
    required String id,
    required String nombre,
    required double pesoKg,
    required double alturaCm,
    required double porcentajeGrasa,
  }) {
    return Usuario(
      id: id,
      nombre: nombre,
      pesoKg: pesoKg,
      alturaCm: alturaCm,
      porcentajeGrasa: porcentajeGrasa,
      fechaRegistro: DateTime.now(),
      rangosPorMusculo: _gruposMuscularesIniciales(),
    );
  }

  static List<RangoPorMusculo> _gruposMuscularesIniciales() {
    final grupos = [
      'Pecho',
      'Espalda',
      'Piernas',
      'Hombros',
      'Bíceps',
      'Tríceps',
      'Antebrazos',
      'Abdominales',
      'Glúteos',
    ];

    return grupos
        .map((grupo) => RangoPorMusculo.desdeVolumen(
              grupoMuscular: grupo,
              volumenUltimoMes: 0.0,
            ))
        .toList();
  }

  /// Actualiza el volumen acumulado para un grupo muscular.
  void actualizarVolumenMuscular({
    required String grupoMuscular,
    required double volumenUltimoMes,
  }) {
    final indice = rangosPorMusculo
        .indexWhere((rango) => rango.grupoMuscular == grupoMuscular);
    if (indice != -1) {
      rangosPorMusculo[indice] = RangoPorMusculo.desdeVolumen(
        grupoMuscular: grupoMuscular,
        volumenUltimoMes: volumenUltimoMes,
      );
    } else {
      rangosPorMusculo.add(RangoPorMusculo.desdeVolumen(
        grupoMuscular: grupoMuscular,
        volumenUltimoMes: volumenUltimoMes,
      ));
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'pesoKg': pesoKg,
      'alturaCm': alturaCm,
      'porcentajeGrasa': porcentajeGrasa,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'rangosPorMusculo': rangosPorMusculo.map((r) => r.toJson()).toList(),
    };
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      pesoKg: (json['pesoKg'] as num).toDouble(),
      alturaCm: (json['alturaCm'] as num).toDouble(),
      porcentajeGrasa: (json['porcentajeGrasa'] as num).toDouble(),
      fechaRegistro: DateTime.parse(json['fechaRegistro'] as String),
      rangosPorMusculo: (json['rangosPorMusculo'] as List<dynamic>)
          .map((item) => RangoPorMusculo.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Índice de masa corporal.
  double get imc {
    final alturaMetros = alturaCm / 100;
    return pesoKg / (alturaMetros * alturaMetros);
  }

  /// Devuelve una descripción resumida del usuario.
  String get descripcionPerfil {
    return 'Usuario: $nombre · Peso: ${pesoKg.toStringAsFixed(1)} kg · Altura: ${alturaCm.toStringAsFixed(0)} cm · Grasa corporal: ${porcentajeGrasa.toStringAsFixed(1)}%';
  }
}
