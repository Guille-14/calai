import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/symmetry/symmetry_progression_service.dart';
import '../../core/symmetry/symmetry_workout_ledger.dart';
import '../../core/symmetry/symmetry_rank_system.dart';
import '../../core/utils/date_key.dart';
import '../../core/utils/workout_calories.dart';
import '../../data/local/preference_manager.dart';
import '../../data/services/ai_gateway.dart';
import '../widgets/hevy_sync_button_widget.dart';

class SymmetryWorkoutScreen extends StatefulWidget {
  const SymmetryWorkoutScreen({super.key});

  @override
  State<SymmetryWorkoutScreen> createState() => _SymmetryWorkoutScreenState();
}

class _SymmetryWorkoutScreenState extends State<SymmetryWorkoutScreen>
    with AutomaticKeepAliveClientMixin<SymmetryWorkoutScreen> {
  @override
  bool get wantKeepAlive => true;

  final SymmetryProgressionService _symmetryService =
      SymmetryProgressionService();
  bool _isLoading = true;
  bool _isWorkoutActive = false;
  double _sessionXP = 0;
  List<ExerciseRecord> _sessionExercises = [];
  double _sessionTonnage = 0;
  String _selectedMuscleGroup = 'pecho';
  DateTime? _workoutStartTime;

  final Map<String, String> muscleGroupNames = {
    'pecho': 'Pecho',
    'espalda': 'Espalda',
    'hombros': 'Hombros',
    'biceps': 'Bíceps',
    'triceps': 'Tríceps',
    'cuadriceps': 'Cuádriceps',
    'isquiotibiales': 'Isquiotibiales',
    'gluteos': 'Glúteos',
    'pantorrillas': 'Pantorrillas',
    'abdomen': 'Abdomen',
  };

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _symmetryService.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _isWorkoutActive ? 'Entrenamiento' : 'Nuevo Entrenamiento',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isWorkoutActive)
            TextButton(
              onPressed: _finishWorkout,
              child: const Text(
                'Finalizar',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isWorkoutActive ? _buildActiveWorkout() : _buildStartWorkout(),
    );
  }

  Widget _buildStartWorkout() {
    final progress = _symmetryService.getProgress();
    final recommendations = _symmetryService.getWorkoutRecommendations();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Opcional: importar entrenamientos de Hevy vía Health Connect
          // (tap abre la pantalla de sync, long-press hace sync rápida).
          const HevySyncButtonWidget(),
          const SizedBox(height: 16),
          _buildXPCard(progress),
          const SizedBox(height: 20),
          _buildRecommendationsCard(recommendations),
          const SizedBox(height: 20),
          _buildMuscleGroupSelector(),
          const SizedBox(height: 24),
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildXPCard(SymmetryProgress progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: progress.currentRank.color.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_outline, color: progress.currentRank.color, size: 28),
              const SizedBox(width: 8),
              Text(
                progress.currentRank.displayName,
                style: TextStyle(
                  color: progress.currentRank.color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${progress.totalXP.toStringAsFixed(0)} XP totales',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.rankProgress,
            color: progress.currentRank.color,
            backgroundColor: AppColors.divider,
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hoy: +${progress.dailyXP.toStringAsFixed(0)} XP',
                style: const TextStyle(color: AppColors.accent, fontSize: 12),
              ),
              if (progress.metProteinGoal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'x1.2 MULTI',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(List<String> recommendations) {
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Recomendaciones',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: AppColors.accent)),
                    Expanded(
                      child: Text(
                        rec,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildMuscleGroupSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona grupo muscular',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: muscleGroupNames.entries.map((entry) {
            final isSelected = _selectedMuscleGroup == entry.key;
            return GestureDetector(
              onTap: () => setState(() => _selectedMuscleGroup = entry.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.accent : AppColors.divider,
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected ? AppColors.background : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return ElevatedButton(
      onPressed: _startWorkout,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center_outlined, size: 24),
          SizedBox(width: 12),
          Text(
            'INICIAR ENTRENAMIENTO',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWorkout() {
    return Column(
      children: [
        _buildSessionHUD(),
        Expanded(
          child: _buildExerciseList(),
        ),
        _buildAddExerciseButton(),
      ],
    );
  }

  Widget _buildSessionHUD() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildHUDItem(
            icon: Icons.fitness_center_outlined,
            label: 'Ejercicios',
            value: '${_sessionExercises.length}',
          ),
          _buildHUDItem(
            icon: Icons.monitor_weight_outlined,
            label: 'Tonelaje',
            value: '${_sessionTonnage.toStringAsFixed(0)}kg',
          ),
          _buildHUDItem(
            icon: Icons.star_outline,
            label: 'XP',
            value: '+${_sessionXP.toStringAsFixed(0)}',
            valueColor: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildHUDItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildExerciseList() {
    if (_sessionExercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 64,
              color: AppColors.textPrimary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              'Añade tu primer ejercicio',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessionExercises.length,
      itemBuilder: (context, index) {
        final exercise = _sessionExercises[index];
        return _buildExerciseCard(exercise, index);
      },
    );
  }

  Widget _buildExerciseCard(ExerciseRecord exercise, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.sets} series × ${exercise.reps} reps @ ${exercise.weight.toStringAsFixed(0)}kg',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${exercise.tonnage.toStringAsFixed(0)} kg',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error, size: 20),
                onPressed: () => _removeExercise(index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddExerciseButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: _showAddExerciseDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.accent),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppColors.accent),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: _scanRoutine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, color: AppColors.background),
                    SizedBox(width: 8),
                    Text(
                      'ESCANEAR SYMMETRY',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanRoutine() async {
    final picker = ImagePicker();
    final XFile? xfile;
    try {
      xfile = await picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      debugPrint('Symmetry: error abriendo la galería: $e');
      return;
    }
    if (xfile == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );

    // La lectura del fichero y la llamada a la IA pueden fallar. Sin este
    // try/catch el diálogo de carga se quedaba bloqueando la pantalla para
    // siempre y el error subía sin gestionar.
    final SymmetryRoutineAnalysisResult result;
    try {
      final bytes = await xfile.readAsBytes();
      result = await AiGateway.analyzeSymmetryRoutineFromBytes(
          bytes, _selectedMuscleGroup);
    } catch (e) {
      debugPrint('Symmetry: error analizando la rutina: $e');
      if (!mounted) return;
      Navigator.pop(context); // cierra el loader pase lo que pase
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo leer la rutina. Inténtalo de nuevo.'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context); // close loader

    if (result.isError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Error leyendo la rutina'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (result.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se detectaron ejercicios en la imagen.'), backgroundColor: AppColors.accent),
      );
      return;
    }

    setState(() {
      for (final ex in result.exercises) {
        final record = ExerciseRecord(
          name: ex.name,
          muscleGroup: _selectedMuscleGroup,
          weight: ex.weight,
          sets: ex.sets,
          reps: ex.reps,
        );
        _sessionExercises.add(record);
        _sessionTonnage += record.tonnage;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡${result.exercises.length} ejercicios importados!'),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  void _startWorkout() {
    setState(() {
      _isWorkoutActive = true;
      _sessionXP = 0;
      _sessionExercises = [];
      _sessionTonnage = 0;
      _workoutStartTime = DateTime.now();
    });
  }

  void _showAddExerciseDialog() {
    final nameController = TextEditingController();
    final weightController = TextEditingController();
    final setsController = TextEditingController(text: '3');
    final repsController = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Añadir Ejercicio',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nombre del ejercicio',
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: weightController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Peso (kg)',
                            hintStyle: const TextStyle(color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: setsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Series',
                            hintStyle: const TextStyle(color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: repsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Reps',
                            hintStyle: const TextStyle(color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty &&
                          weightController.text.isNotEmpty) {
                        _addExercise(
                          nameController.text,
                          double.tryParse(weightController.text) ?? 0,
                          int.tryParse(setsController.text) ?? 3,
                          int.tryParse(repsController.text) ?? 10,
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('AÑADIR'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      weightController.dispose();
      setsController.dispose();
      repsController.dispose();
    });
  }

  void _addExercise(String name, double weight, int sets, int reps) {
    final exercise = ExerciseRecord(
      name: name,
      muscleGroup: _selectedMuscleGroup,
      weight: weight,
      sets: sets,
      reps: reps,
    );

    setState(() {
      _sessionExercises.add(exercise);
      _sessionTonnage += exercise.tonnage;
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _sessionTonnage -= _sessionExercises[index].tonnage;
      _sessionExercises.removeAt(index);
    });
  }

  Future<void> _finishWorkout() async {
    if (_sessionExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Añade al menos un ejercicio'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Duración real de la sesión; antes se inventaba dividiendo el tonelaje
    // entre 50, contaminando estadísticas e historial.
    final start = _workoutStartTime;
    final durationMinutes = start == null
        ? 0
        : DateTime.now().difference(start).inMinutes;

    final xpEarned = await _symmetryService.addWorkout(
      tonnage: _sessionTonnage,
      durationMinutes: durationMinutes < 1 ? 1 : durationMinutes,
      muscleGroup: _selectedMuscleGroup,
      exercises: _sessionExercises,
    );

    // Feedback entrenamiento -> nutrición (DESACTIVADO por defecto): si el
    // usuario lo activó en Perfil, se credita el gasto estimado del
    // entrenamiento en el presupuesto calórico del día
    // (pref calorie_adjustment_YYYY-MM-DD, lo aplica Home).
    await _creditWorkoutCaloriesIfEnabled(durationMinutes);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: AppColors.accent,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                '¡Entrenamiento completado!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '+${xpEarned.toStringAsFixed(0)} XP',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${_sessionExercises.length} ejercicios • ${_sessionTonnage.toStringAsFixed(0)} kg',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isWorkoutActive = false;
                  _sessionXP = 0;
                  _sessionExercises = [];
                  _sessionTonnage = 0;
                  _workoutStartTime = null;
                });
              },
              child: const Text('CERRAR'),
            ),
          ],
        ),
      );
    }
  }

  /// Si el toggle 'creditar calorías quemadas' está activo, suma las kcal
  /// estimadas (fórmula MET, ver core/utils/workout_calories.dart) al
  /// ajuste calórico de hoy. El peso se toma del perfil (fallback 75 kg).
  /// Nunca rompe el flujo de finalización del entrenamiento.
  Future<void> _creditWorkoutCaloriesIfEnabled(int durationMinutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(kCreditWorkoutCaloriesKey) ?? false;
      if (!enabled) return;

      // Sin perfil, la estimación usa el fallback de 75 kg.
      final weight = PreferenceManager(prefs).getUserData()?.weight ?? 75;
      final kcal = estimateWorkoutCalories(
        minutes: durationMinutes,
        weightKg: weight,
      );
      if (kcal <= 0) return;

      final key = kCalorieAdjustmentKeyPrefix + formatDateKey(DateTime.now());
      await prefs.setDouble(key, (prefs.getDouble(key) ?? 0) + kcal);
    } catch (e) {
      debugPrint('Symmetry: error creditando calorías de entrenamiento: $e');
    }
  }
}
