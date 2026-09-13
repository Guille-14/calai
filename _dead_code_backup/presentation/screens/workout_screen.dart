
import 'package:flutter/material.dart';

import '../../models/workout_models.dart';
import '../../data/services/workout_storage.dart';
import '../../core/theme/app_constants.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final _workoutStorage = WorkoutStorageService();
  final List<WorkoutExercise> _exercises = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize with one empty exercise if none exists
    if (_exercises.isEmpty) {
      _exercises.add(WorkoutExercise(name: '', sets: []));
    }
  }

  void _addExercise() {
    setState(() {
      _exercises.add(WorkoutExercise(name: '', sets: []));
    });
  }

  void _removeExercise(int index) {
    if (_exercises.length > 1) {
      setState(() {
        _exercises.removeAt(index);
      });
    }
  }

  void _addSet(int exerciseIndex) async {
    final exercise = _exercises[exerciseIndex];
    final setNumber = exercise.sets.length + 1;
    final previousPerformance =
        await _workoutStorage.getPreviousPerformance(exercise.name, setNumber);
    setState(() {
      exercise.sets.add(ExerciseSet(
        setNumber: setNumber,
        weight: 0.0,
        reps: 0,
        isCompleted: false,
        previousPerformance: previousPerformance,
      ));
    });
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    if (_exercises[exerciseIndex].sets.length > 1) {
      setState(() {
        _exercises[exerciseIndex].sets.removeAt(setIndex);
      });
    }
  }

  void _updateSetWeight(int exerciseIndex, int setIndex, String value) {
    setState(() {
      final double? weight = double.tryParse(value);
      if (weight != null) {
        _exercises[exerciseIndex].sets[setIndex].weight = weight;
      }
    });
  }

  void _updateSetReps(int exerciseIndex, int setIndex, String value) {
    setState(() {
      final int? reps = int.tryParse(value);
      if (reps != null) {
        _exercises[exerciseIndex].sets[setIndex].reps = reps;
      }
    });
  }

  void _toggleSetCompletion(int exerciseIndex, int setIndex) {
    setState(() {
      final set = _exercises[exerciseIndex].sets[setIndex];
      set.isCompleted = !set.isCompleted;
    });
  }

  Future<void> _saveWorkout() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Calculate duration (for simplicity, we'll use a fixed value or time since start)
      final durationMinutes =
          45; // Placeholder - in a real app, you'd track actual time

      final workoutSession = WorkoutSession(
        date: DateTime.now(),
        durationMinutes: durationMinutes,
        exercises: List.from(_exercises),
      );

      await _workoutStorage.saveSession(workoutSession);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrenamiento guardado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        // Reset for next workout
        setState(() {
          _exercises.clear();
          _exercises.add(WorkoutExercise(name: '', sets: []));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Entrenamiento de Fuerza',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _exercises.clear();
                _exercises.add(WorkoutExercise(name: '', sets: []));
              });
            },
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, index) => _buildExerciseCard(index),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isSaving
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton(
                onPressed: _saveWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCalories,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  'Finalizar Entrenamiento',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildExerciseCard(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface.withValues(alpha: 0.9),
              AppColors.surface,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExerciseHeader(exerciseIndex),
            Divider(height: 1),
            _buildSetsTable(exerciseIndex),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _addSet(exerciseIndex),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir Serie'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentCalories,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseHeader(int exerciseIndex) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              autofocus: exerciseIndex == 0 && _exercises.length == 1,
              decoration: const InputDecoration(
                labelText: 'Ejercicio',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              onChanged: (value) {
                setState(() {
                  _exercises[exerciseIndex].name = value;
                });
              },
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _removeExercise(exerciseIndex),
            tooltip: 'Eliminar ejercicio',
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildSetsTable(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    if (exercise.sets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Añade series para comenzar',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exercise.sets.length,
      itemBuilder: (context, setIndex) =>
          _buildSetRow(exerciseIndex, setIndex, exercise.sets[setIndex]),
    );
  }

  Widget _buildSetRow(int exerciseIndex, int setIndex, ExerciseSet set) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.surface.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Serie number
            Container(
              width: 40,
              alignment: Alignment.centerLeft,
              child: Text(
                '${set.setNumber}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Previous performance
            Expanded(
              flex: 2,
              child: Text(
                set.previousPerformance ?? '-',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Weight input
            Expanded(
              flex: 1,
              child: TextField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  filled: true,
                  fillColor: AppColors.surface.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppColors.accentCalories.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                onChanged: (value) =>
                    _updateSetWeight(exerciseIndex, setIndex, value),
              ),
            ),
            const SizedBox(width: 8),
            // Reps input
            Expanded(
              flex: 1,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  filled: true,
                  fillColor: AppColors.surface.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppColors.accentCalories.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                onChanged: (value) =>
                    _updateSetReps(exerciseIndex, setIndex, value),
              ),
            ),
            const SizedBox(width: 8),
            // Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: set.isCompleted,
                activeColor: AppColors.accentCalories,
                checkColor: Colors.white,
                onChanged: (_) => _toggleSetCompletion(exerciseIndex, setIndex),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
