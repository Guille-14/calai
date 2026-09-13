import 'package:calorie_lens/models/exercise_library.dart';

/// Servicio de base de datos de ejercicios con videos tutoriales y fotos
class ExerciseDatabaseService {
  static final ExerciseDatabaseService _instance =
      ExerciseDatabaseService._internal();

  factory ExerciseDatabaseService() {
    return _instance;
  }

  ExerciseDatabaseService._internal();

  /// Base de datos completa de ejercicios en español
  late final List<Exercise> _exercises = _initializeExercises();

  String _getThumb(String videoUrl) {
    if (videoUrl.isEmpty) return '';
    final videoId = videoUrl.split('/').last;
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  /// Inicializa la base de datos de ejercicios con videos
  List<Exercise> _initializeExercises() {
    final rawData = [
      // PECHO
      ['bench_press', 'Press de Banca', 'Pecho', 'intermedio', 'vcBig7D1nvs', 'Ejercicio fundamental de fuerza para el pecho usando barra.', 'Mantén los pies planos, baja la barra al centro del pecho, empuja explosivamente', 'Barra'],
      ['incline_bench_press', 'Press de Banca Inclinado', 'Pecho', 'intermedio', 'SrqOu55lrYU', 'Enfocado en las fibras superiores del pecho. Banco a 30-45 grados.', 'Toca el pecho superior, controla el descenso, codos hacia adentro', 'Barra'],
      ['pec_deck_fly', 'Aperturas en Máquina', 'Pecho', 'principiante', 'O-L_n-b_27M', 'Aislamiento de pecho usando máquina. Enfócate en apretar.', 'Aprieta al centro, estira al volver, no dejes que el peso choque', 'Máquina'],
      ['flat_dumbbell_press', 'Press con Mancuernas', 'Pecho', 'principiante', '86UAX7Xp0wQ', 'Constructor de pecho usando mancuernas para mayor rango.', 'Mantén el control, aprieta arriba, pies plantados', 'Mancuernas'],
      ['dumbbell_fly', 'Aperturas con Mancuernas', 'Pecho', 'principiante', 'eozdVDA78K0', 'Ejercicio de aislamiento para amplitud de pecho.', 'Ligera flexión de codos, estira abajo, aprieta arriba', 'Mancuernas'],
      ['cable_crossover', 'Cruce de Poleas', 'Pecho', 'principiante', 'xvWvVHIy9sc', 'Aislamiento en poleas para definición de pecho.', 'Paso adelante para tensión, pecho arriba, aprieta los agarres', 'Poleas'],
      ['chest_press_machine', 'Press de Pecho en Máquina', 'Pecho', 'principiante', 'xvWvVHIy9sc', 'Desarrollo de pecho seguro y efectivo.', 'Ajusta la altura del asiento, empuja adelante, retorno controlado', 'Máquina'],
      ['push-ups', 'Flexiones', 'Pecho', 'principiante', 'pSHjTRCQxzw', 'Movimiento con peso corporal para pecho y tríceps.', 'Cuerpo recto, pecho al suelo, subida explosiva', 'Peso Corporal'],
      ['dips_(chest)', 'Fondos (Pecho)', 'Pecho', 'intermedio', '2-LAMcpzODU', 'Fondos enfocados en la parte inferior del pecho.', 'Inclínate adelante, codos ligeramente afuera, rango completo', 'Peso Corporal'],

      // ESPALDA
      ['deadlift', 'Peso Muerto', 'Espalda/Piernas', 'avanzado', '6T_NqExnuxI', 'El rey de los levantamientos. Potencia total.', 'Barra pegada a espinillas, espalda plana, bisagra de cadera', 'Barra'],
      ['barbell_row', 'Remo con Barra', 'Espalda', 'intermedio', '9efgcAjQW70', 'Constructor de masa para la densidad de la espalda.', 'Espalda plana, tira hacia la cintura, aprieta escápulas', 'Barra'],
      ['pull-ups', 'Dominadas', 'Espalda', 'intermedio', 'eGo4IYlbE5g', 'Tracción vertical definitiva para amplitud.', 'Empieza colgado, barbilla sobre la barra, descenso lento', 'Peso Corporal'],
      ['chin-ups', 'Dominadas Supinas', 'Espalda', 'principiante', 'H0O_A-T7VvM', 'Tracción vertical con agarre supino. Más bíceps.', 'Pecho a la barra, extensión completa, aprieta dorsales', 'Peso Corporal'],
      ['lat_pulldown', 'Jalón al Pecho', 'Espalda', 'principiante', 'CAwf7n6pntg', 'Tracción vertical en máquina para amplitud.', 'Tira al pecho superior, inclínate un poco, siente el estiramiento', 'Máquina'],
      ['cable_row', 'Remo en Polea', 'Espalda', 'principiante', 'GZbfZ033f74', 'Remo sentado para la zona media de la espalda.', 'No balancees el torso, tira al ombligo, hombros atrás', 'Polea'],
      ['single_arm_dumbbell_row', 'Remo con Mancuerna', 'Espalda', 'principiante', 'dFzZpLSRuS0', 'Aislamiento para densidad y estabilidad.', 'Una mano en banco, tira a la cadera, estiramiento total', 'Mancuerna'],
      ['back_hyperextensions', 'Hiperextensiones', 'Espalda', 'principiante', 'unXvshqV1Zk', 'Fortalece la espalda baja e isquios.', 'Bisagra en cadera, no sobreextiendas, core tenso', 'Máquina'],

      // HOMBROS
      ['overhead_press', 'Press Militar', 'Hombros', 'intermedio', '2yjwHe44760', 'Empuje vertical fundamental para hombros.', 'Aprieta glúteos, pasa la barra cerca de la cara, bloqueo total', 'Barra'],
      ['arnold_press', 'Press Arnold', 'Hombros', 'intermedio', '6Z15_W6v8t4', 'Press con rotación desarrollado por Arnold.', 'Rota las palmas al subir, rango completo, controlado', 'Mancuerna'],
      ['lateral_raises', 'Elevaciones Laterales', 'Hombros', 'principiante', 'Fj-y5M5y2QY', 'Aislamiento del deltoides lateral.', 'Lidera con los codos, manos ligeramente rotadas, baja lento', 'Mancuerna'],
      ['face_pulls', 'Face Pulls', 'Hombros', 'principiante', 'VzU4aJ3G-gE', 'Salud del hombro y deltoides posterior.', 'Tira hacia la frente, separa la cuerda, mantén el apretón', 'Polea'],
      ['front_raises', 'Elevaciones Frontales', 'Hombros', 'principiante', 'hRJ6h386_jM', 'Aislamiento del deltoides anterior.', 'Brazo recto, sube a nivel de los ojos, sin balanceo', 'Mancuerna'],
      ['rear_delt_fly', 'Aperturas Posteriores', 'Hombros', 'principiante', '71Gvc5YvVqU', 'Aislamiento del deltoides posterior.', 'Ligera flexión de codos, aprieta deltoides traseros', 'Mancuerna'],

      // BRAZOS
      ['bicep_curls', 'Curl de Bíceps', 'Brazos', 'principiante', 'uO_CNYidNw0', 'Clásico constructor de masa para bíceps.', 'Sin balanceo, extensión completa, aprieta arriba', 'Mancuerna'],
      ['hammer_curls', 'Curl Martillo', 'Brazos', 'principiante', 'kY3P98y-Y90', 'Desarrollo del braquiorradial y antebrazo.', 'Agarre neutro, codos pegados, negativa lenta', 'Mancuerna'],
      ['preacher_curls', 'Curl Predicador', 'Brazos', 'principiante', 'v87_c6rO_5k', 'Aislamiento estricto de bíceps.', 'Pecho en el pad, extensión completa, aprieta fuerte', 'Barra'],
      ['spider_curls', 'Curl Araña', 'Brazos', 'principiante', 'u3qB-I__2G8', 'Aislamiento de bíceps en ángulo inclinado.', 'Pecho en banco inclinado, brazos cuelgan, curl arriba', 'Barra'],
      ['tricep_pushdown', 'Extensiones de Tríceps', 'Brazos', 'principiante', 'vB5OHsJ4A2E', 'Aislamiento de tríceps en polea.', 'Codos bloqueados, extensión total, tensión constante', 'Polea'],
      ['skull_crushers', 'Press Francés', 'Brazos', 'intermedio', 'd_KZxkYZX6c', 'Constructor de masa para tríceps.', 'Baja a la frente, bloquea brazos, codos cerrados', 'Barra'],
      ['close_grip_bench_press', 'Press Agarre Cerrado', 'Brazos', 'intermedio', 'GjU707U9wQk', 'Compuesto para tríceps y pecho.', 'Manos a ancho de hombros, baja al pecho, explota', 'Barra'],

      // PIERNAS
      ['squat', 'Sentadilla', 'Piernas', 'avanzado', 'nFAscG0Xiy0', 'Base del crecimiento de piernas.', 'Baja de la paralela, pecho arriba, talones apoyados', 'Barra'],
      ['leg_press', 'Prensa', 'Piernas', 'principiante', 'yZmx_7ig1D8', 'Entrenamiento de gran volumen para piernas.', 'No bloquees rodillas, rango completo, pies al centro', 'Máquina'],
      ['bulgarian_split_squat', 'Sentadilla Búlgara', 'Piernas', 'intermedio', '2C-uNgKwPLE', 'Potencia unilateral de piernas y glúteos.', 'Pie trasero elevado, pecho erguido, empuja con el talón', 'Mancuernas'],
      ['leg_extensions', 'Extensiones de Pierna', 'Piernas', 'principiante', 'm0fo7u9fF_0', 'Aislamiento de cuádriceps.', 'Aprieta arriba, control lento, alinea rodillas', 'Máquina'],
      ['leg_curls', 'Curl de Pierna', 'Piernas', 'principiante', 'unXvshqV1Zk', 'Aislamiento de isquios.', 'Mantén la cadera abajo, aprieta fuerte, retorno controlado', 'Máquina'],
      ['romanian_deadlift', 'Peso Muerto Rumano', 'Piernas', 'intermedio', '2rnYLKHmRdw', 'Bisagra para isquios y glúteos.', 'Bisagra en cadera, barra pegada a piernas, siente tensión', 'Barra'],
      ['calf_raises', 'Gemelos', 'Piernas', 'principiante', 'xvWvVHIy9sc', 'Desarrollo de pantorrillas.', 'Estiramiento abajo, explosión arriba, mantén el pico', 'Máquina'],

      // CORE
      ['plank', 'Plancha', 'Abdominales', 'principiante', 'pSHjTRCQxzw', 'Estabilidad isométrica del core.', 'Aprieta glúteos, empuja el suelo, respira profundo', 'Peso Corporal'],
      ['hanging_leg_raises', 'Elevación de Piernas', 'Abdominales', 'avanzado', 'jWvE6JhiXis', 'Potencia abdominal superior e inferior.', 'Sube con el abdomen, sin balanceo, descenso lento', 'Peso Corporal'],
      ['crunches', 'Crunches', 'Abdominales', 'principiante', 'unXvshqV1Zk', 'Desarrollo abdominal básico.', 'Espalda baja plana, aprieta el abdomen, barbilla arriba', 'Peso Corporal'],
    ];

    return rawData.map((data) {
      final id = data[0];
      final name = data[1];
      final muscleGroup = data[2];
      final difficulty = data[3];
      final vidId = data[4];
      final videoUrl = 'https://www.youtube.com/embed/$vidId';
      final description = data[5];
      final tips = (data[6]).split(', ');
      final equipment = data[7];

      return Exercise(
        id: id,
        name: name,
        muscleGroup: muscleGroup,
        difficulty: difficulty,
        videoUrl: videoUrl,
        thumbnailUrl: _getThumb(videoUrl),
        description: description,
        tips: tips,
        equipment: equipment,
      );
    }).toList();
  }

  /// Obtiene todos los ejercicios
  List<Exercise> getAllExercises() => List.from(_exercises);

  /// Obtiene ejercicios por grupo muscular
  List<Exercise> getExercisesByMuscleGroup(String muscleGroup) {
    return _exercises
        .where((e) => e.muscleGroup.toLowerCase() == muscleGroup.toLowerCase())
        .toList();
  }

  /// Busca ejercicios por nombre
  List<Exercise> searchExercises(String query) {
    final lowerQuery = query.toLowerCase();
    return _exercises
        .where((e) => e.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Obtiene un ejercicio por ID
  Exercise? getExerciseById(String id) {
    try {
      final normalizedId = id
          .toLowerCase()
          .trim()
          .replaceAll(' ', '_')
          .replaceAll('-', '_')
          .replaceAll('(', '')
          .replaceAll(')', '');
          
      return _exercises.firstWhere((e) {
        final exId = e.id.replaceAll('-', '_').replaceAll('(', '').replaceAll(')', '');
        final exName = e.name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
        return exId == normalizedId || exName == normalizedId;
      });
    } catch (e) {
      return null;
    }
  }

  /// Obtiene ejercicios relacionados
  List<Exercise> getRelatedExercises(String muscleGroup, {String? excludeId}) {
    return _exercises
        .where((e) =>
            e.muscleGroup.toLowerCase() == muscleGroup.toLowerCase() &&
            (excludeId == null || e.id != excludeId))
        .toList();
  }
}
