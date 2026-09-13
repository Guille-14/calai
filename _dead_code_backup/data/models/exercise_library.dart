class ExerciseLibrary {
  final String name;
  final String category;
  final String muscle;
  final String? videoUrl;
  final String? description;

  const ExerciseLibrary({
    required this.name,
    required this.category,
    required this.muscle,
    this.videoUrl,
    this.description,
  });

  static const List<ExerciseLibrary> all = [
    // ── Pecho ──
    ExerciseLibrary(name: 'Press de Banca', category: 'Barra', muscle: 'Pecho'),
    ExerciseLibrary(name: 'Press de Banca Inclinado', category: 'Barra', muscle: 'Pecho'),
    ExerciseLibrary(name: 'Aperturas en Máquina', category: 'Máquina', muscle: 'Pecho'),
    ExerciseLibrary(name: 'Press con Mancuernas', category: 'Mancuerna', muscle: 'Pecho'),
    ExerciseLibrary(name: 'Aperturas con Mancuernas', category: 'Mancuerna', muscle: 'Pecho'),
    ExerciseLibrary(name: 'Cruce de Poleas', category: 'Polea', muscle: 'Pecho'),
    ExerciseLibrary(name: 'Press de Pecho en Máquina', category: 'Máquina', muscle: 'Pecho'),
    ExerciseLibrary(name: 'Flexiones', category: 'Peso Corporal', muscle: 'Pecho'),
    ExerciseLibrary(name: 'Fondos (Pecho)', category: 'Peso Corporal', muscle: 'Pecho'),

    // ── Espalda ──
    ExerciseLibrary(name: 'Peso Muerto', category: 'Barra', muscle: 'Espalda'),
    ExerciseLibrary(name: 'Remo con Barra', category: 'Barra', muscle: 'Espalda'),
    ExerciseLibrary(name: 'Dominadas', category: 'Peso Corporal', muscle: 'Espalda'),
    ExerciseLibrary(name: 'Dominadas Supinas', category: 'Peso Corporal', muscle: 'Espalda'),
    ExerciseLibrary(name: 'Jalón al Pecho', category: 'Polea', muscle: 'Espalda'),
    ExerciseLibrary(name: 'Remo en Polea', category: 'Polea', muscle: 'Espalda'),
    ExerciseLibrary(name: 'Remo con Mancuerna', category: 'Mancuerna', muscle: 'Espalda'),
    ExerciseLibrary(name: 'Hiperextensiones', category: 'Máquina', muscle: 'Espalda'),

    // ── Hombros ──
    ExerciseLibrary(name: 'Press Militar', category: 'Barra', muscle: 'Hombros'),
    ExerciseLibrary(name: 'Press Arnold', category: 'Mancuerna', muscle: 'Hombros'),
    ExerciseLibrary(name: 'Elevaciones Laterales', category: 'Mancuerna', muscle: 'Hombros'),
    ExerciseLibrary(name: 'Face Pulls', category: 'Polea', muscle: 'Hombros'),
    ExerciseLibrary(name: 'Elevaciones Frontales', category: 'Mancuerna', muscle: 'Hombros'),
    ExerciseLibrary(name: 'Aperturas Posteriores', category: 'Mancuerna', muscle: 'Hombros'),

    // ── Bíceps ──
    ExerciseLibrary(name: 'Curl de Bíceps', category: 'Mancuerna', muscle: 'Bíceps'),
    ExerciseLibrary(name: 'Curl Martillo', category: 'Mancuerna', muscle: 'Bíceps'),
    ExerciseLibrary(name: 'Curl Predicador', category: 'Barra', muscle: 'Bíceps'),
    ExerciseLibrary(name: 'Curl Araña', category: 'Barra', muscle: 'Bíceps'),

    // ── Tríceps ──
    ExerciseLibrary(name: 'Extensiones de Tríceps', category: 'Polea', muscle: 'Tríceps'),
    ExerciseLibrary(name: 'Press Francés', category: 'Barra', muscle: 'Tríceps'),
    ExerciseLibrary(name: 'Press Agarre Cerrado', category: 'Barra', muscle: 'Tríceps'),
    ExerciseLibrary(name: 'Fondos (Tríceps)', category: 'Peso Corporal', muscle: 'Tríceps'),

    // ── Piernas ──
    ExerciseLibrary(name: 'Sentadilla', category: 'Barra', muscle: 'Piernas'),
    ExerciseLibrary(name: 'Prensa', category: 'Máquina', muscle: 'Piernas'),
    ExerciseLibrary(name: 'Sentadilla Búlgara', category: 'Mancuerna', muscle: 'Piernas'),
    ExerciseLibrary(name: 'Extensiones de Pierna', category: 'Máquina', muscle: 'Piernas'),
    ExerciseLibrary(name: 'Curl de Pierna', category: 'Máquina', muscle: 'Piernas'),
    ExerciseLibrary(name: 'Peso Muerto Rumano', category: 'Barra', muscle: 'Piernas'),
    ExerciseLibrary(name: 'Gemelos', category: 'Máquina', muscle: 'Piernas'),

    // ── Core ──
    ExerciseLibrary(name: 'Plancha', category: 'Peso Corporal', muscle: 'Abdominales'),
    ExerciseLibrary(name: 'Elevación de Piernas', category: 'Peso Corporal', muscle: 'Abdominales'),
    ExerciseLibrary(name: 'Crunches', category: 'Peso Corporal', muscle: 'Abdominales'),
  ];

  static List<String> get categories {
    return ['Todos', 'Barra', 'Mancuerna', 'Polea', 'Máquina', 'Peso Corporal'];
  }

  static List<String> get muscles {
    return [
      'Todos',
      'Pecho',
      'Espalda',
      'Hombros',
      'Bíceps',
      'Tríceps',
      'Piernas',
      'Abdominales',
    ];
  }

  static List<ExerciseLibrary> filter({
    String? category,
    String? muscle,
    String? search,
  }) {
    var result = all;
    if (category != null && category != 'Todos' && category != 'All') {
      result = result.where((e) => e.category == category).toList();
    }
    if (muscle != null && muscle != 'Todos' && muscle != 'All') {
      result = result.where((e) => e.muscle == muscle).toList();
    }
    if (search != null && search.isNotEmpty) {
      final lower = search.toLowerCase();
      result = result.where((e) => e.name.toLowerCase().contains(lower)).toList();
    }
    return result;
  }
}
