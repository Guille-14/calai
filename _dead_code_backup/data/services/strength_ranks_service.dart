import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/strength_ranks_model.dart';
import '../../models/workout_models.dart';

class StrengthRanksService {
  static const String _bodyAnalysisKey = 'body_analysis';

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  // Muscle groups mapping to exercise types
  static const Map<String, List<String>> muscleGroupExercises = {
    'chest': ['bench_press', 'incline_bench_press', 'dumbbell_press'],
    'back': ['deadlift', 'barbell_row', 'lat_pulldown'],
    'legs': ['squat', 'leg_press', 'leg_extension'],
    'shoulders': ['overhead_press', 'lateral_raise', 'shoulder_press'],
    'biceps': ['barbell_curl', 'dumbbell_curl', 'curl_machine'],
    'triceps': ['close_grip_bench_press', 'skull_crushers', 'tricep_dips'],
    'forearms': ['barbell_curl', 'wrist_curl', 'reverse_curl'],
    'abs': ['cable_crunch', 'hanging_leg_raise', 'ab_wheel'],
  };

  static const Map<String, String> muscleGroupColors = {
    'chest': '#FF6B6B',
    'back': '#4ECDC4',
    'legs': '#FFE66D',
    'shoulders': '#95E1D3',
    'biceps': '#C7CEEA',
    'triceps': '#B5EAD7',
    'forearms': '#FFB7B2',
    'abs': '#FFDAC1',
  };

  Future<BodyAnalysis> getBodyAnalysis() async {
    final prefs = await _prefs;
    final json = prefs.getString(_bodyAnalysisKey);

    if (json == null) {
      return _createDefaultBodyAnalysis();
    }

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return BodyAnalysis.fromJson(data);
    } catch (e) {
      return _createDefaultBodyAnalysis();
    }
  }

  Future<void> saveBodyAnalysis(BodyAnalysis analysis) async {
    final prefs = await _prefs;
    await prefs.setString(_bodyAnalysisKey, jsonEncode(analysis.toJson()));
  }

  // Update ranks based on completed workout
  Future<void> updateRanksFromWorkout(WorkoutSession session) async {
    final analysis = await getBodyAnalysis();

    for (var exercise in session.exercises) {
      final muscleGroup = _getMuscleGroupForExercise(exercise.name);
      if (muscleGroup != null && analysis.muscleRanks.containsKey(muscleGroup)) {
        final rank = analysis.muscleRanks[muscleGroup]!;

        // Calculate XP gained from this workout
        double xpGained = 0;
        for (var set in exercise.sets) {
          if (set.isCompleted) {
            xpGained += (set.weight * set.reps) / 10; // Simple XP calculation
          }
        }

        // Update rank
        rank.currentXP += xpGained;
        rank.lastWorkedOut = DateTime.now();
        rank.totalWorkouts += 1;

        // Check for rank up
        while (rank.currentXP >= rank.nextRankXP) {
          rank.currentXP -= rank.nextRankXP;
          rank.currentRank += 1;
          rank.nextRankXP *= 1.15; // 15% increase each rank
        }

        // Update max weight/reps
        for (var set in exercise.sets) {
          if (set.isCompleted && set.weight > rank.maxWeight) {
            rank.maxWeight = set.weight;
            rank.maxReps = set.reps;
          }
        }
      }
    }

    _updateAnalysisStats(analysis);
    await saveBodyAnalysis(analysis);
  }

  // Add XP manually to a muscle group
  Future<void> addXPToMuscle(String muscleGroup, double xp) async {
    final analysis = await getBodyAnalysis();

    if (analysis.muscleRanks.containsKey(muscleGroup)) {
      final rank = analysis.muscleRanks[muscleGroup]!;
      rank.currentXP += xp;

      while (rank.currentXP >= rank.nextRankXP) {
        rank.currentXP -= rank.nextRankXP;
        rank.currentRank += 1;
        rank.nextRankXP *= 1.15;
      }

      _updateAnalysisStats(analysis);
      await saveBodyAnalysis(analysis);
    }
  }

  void _updateAnalysisStats(BodyAnalysis analysis) {
    // Calculate overall level (average of all muscle groups)
    if (analysis.muscleRanks.isNotEmpty) {
      final avgRank = analysis.muscleRanks.values
              .fold<double>(0, (sum, rank) => sum + rank.currentRank) /
          analysis.muscleRanks.length;
      analysis.overallLevel = avgRank.toInt();
    }

    // Find weak and strong points
    final sorted = analysis.muscleRanks.entries.toList()
      ..sort((a, b) => a.value.currentRank.compareTo(b.value.currentRank));

    analysis.weakPoints =
        sorted.take(3).map((e) => e.key).toList();
    analysis.strongPoints = sorted.reversed
        .take(3)
        .map((e) => e.key)
        .toList();
  }

  String? _getMuscleGroupForExercise(String exerciseName) {
    for (final entry in muscleGroupExercises.entries) {
      if (entry.value.any(
          (ex) => exerciseName.toLowerCase().contains(ex.toLowerCase()))) {
        return entry.key;
      }
    }
    return null;
  }

  BodyAnalysis _createDefaultBodyAnalysis() {
    final now = DateTime.now();
    final muscleRanks = <String, MuscleGroupRank>{};

    for (final muscle in muscleGroupColors.entries) {
      muscleRanks[muscle.key] = MuscleGroupRank(
        muscleGroup: muscle.key,
        currentRank: 1,
        currentXP: 0,
        nextRankXP: 100,
        lastWorkedOut: now,
        color: muscle.value,
      );
    }

    return BodyAnalysis(
      muscleRanks: muscleRanks,
      analyzedAt: now,
      overallLevel: 1,
    );
  }
}
