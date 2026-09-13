import 'dart:math';
import 'fitness_memory_profile.dart';

class NutritionIntelligence {
  final FitnessMemoryProfile profile;

  NutritionIntelligence(this.profile);

  NutritionAnalysis analyzeDailyIntake({
    required double caloriesConsumed,
    required double protein,
    required double carbs,
    required double fat,
    required double calorieGoal,
  }) {
    final calorieProgress = caloriesConsumed / calorieGoal;
    final balance = caloriesConsumed - calorieGoal;

    final macroAnalysis = _analyzeMacros(protein, carbs, fat, calorieGoal);
    final deficiency = _detectDeficiencies(protein, carbs, fat, calorieGoal);
    final suggestions =
        _generateSuggestions(protein, carbs, fat, calorieProgress, balance);
    final forecast =
        _forecastDailyIntake(caloriesConsumed, calorieGoal, profile);

    return NutritionAnalysis(
      calorieProgress: calorieProgress,
      calorieBalance: balance,
      isOverGoal: caloriesConsumed > calorieGoal,
      macroAnalysis: macroAnalysis,
      deficiencies: deficiency,
      suggestions: suggestions,
      dailyForecast: forecast,
      weeklyHabits: _analyzeWeeklyHabits(),
      remainingNutrition:
          _calculateRemainingNutrition(protein, carbs, fat, calorieGoal),
    );
  }

  /// Enhanced macro analysis with personalized targets based on user history
  MacroAnalysis _analyzeMacros(
      double protein, double carbs, double fat, double calorieGoal) {
    final proteinCal = protein * 4;
    final carbsCal = carbs * 4;
    final fatCal = fat * 9;
    final totalCal = proteinCal + carbsCal + fatCal;

    if (totalCal == 0) {
      return MacroAnalysis(
        proteinPercentage: 0,
        carbsPercentage: 0,
        fatPercentage: 0,
        proteinGrams: protein,
        carbsGrams: carbs,
        fatGrams: fat,
        status: 'sin_datos',
        personalizedTargets: _getPersonalizedMacroTargets(),
        deviationFromTargets: {},
      );
    }

    final proteinPct = (proteinCal / totalCal * 100);
    final carbsPct = (carbsCal / totalCal * 100);
    final fatPct = (fatCal / totalCal * 100);

    String status;
    if (proteinPct >= 25 &&
        proteinPct <= 35 &&
        carbsPct >= 40 &&
        carbsPct <= 50 &&
        fatPct <= 30) {
      status = 'balanceado';
    } else if (proteinPct > 40) {
      status = 'alto_proteina';
    } else if (carbsPct > 60) {
      status = 'alto_carbohidratos';
    } else if (fatPct > 40) {
      status = 'alto_grasas';
    } else {
      status = 'desbalanceado';
    }

    final targets = _getPersonalizedMacroTargets();
    final deviations = {
      'protein': (proteinPct - targets['protein']!).abs(),
      'carbs': (carbsPct - targets['carbs']!).abs(),
      'fat': (fatPct - targets['fat']!).abs(),
    };

    return MacroAnalysis(
      proteinPercentage: proteinPct,
      carbsPercentage: carbsPct,
      fatPercentage: fatPct,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      status: status,
      personalizedTargets: targets,
      deviationFromTargets: deviations,
    );
  }

  /// Get personalized macro targets based on user's fitness goals and history
  Map<String, double> _getPersonalizedMacroTargets() {
    // Default targets based on general fitness goals
    var proteinTarget = 30.0; // % of calories
    var carbsTarget = 40.0;
    var fatTarget = 30.0;

    // Adjust based on user's exercise patterns if available
    if (profile.exerciseProgression.isNotEmpty) {
      // If user does strength training, increase protein
      final strengthExercises = profile.exerciseProgression.keys
          .where((exercise) => ['sentadilla', 'peso muerto', 'press banca']
              .any((e) => exercise.contains(e)))
          .toList();

      if (strengthExercises.isNotEmpty) {
        proteinTarget = 35.0;
        carbsTarget = 35.0;
        fatTarget = 30.0;
      }
    }

    return {
      'protein': proteinTarget,
      'carbs': carbsTarget,
      'fat': fatTarget,
    };
  }

  List<String> _detectDeficiencies(
      double protein, double carbs, double fat, double calorieGoal) {
    final deficiencies = <String>[];

    final proteinMin = calorieGoal * 0.25 / 4;
    if (protein < proteinMin) {
      deficiencies.add(
          'Proteína por debajo del objetivo mínimo (${proteinMin.toInt()}g)');
    }

    final carbsMin = calorieGoal * 0.40 / 4;
    if (carbs < carbsMin) {
      deficiencies.add('Carbohidratos bajos. Considera añadir más.');
    }

    if (protein < 30) {
      deficiencies
          .add('Ingesta de proteína insuficiente para recuperación muscular.');
    }

    if (fat < 20 && calorieGoal > 1500) {
      deficiencies
          .add('Grasas muy bajas. Necesarias para absorción de vitaminas.');
    }

    return deficiencies;
  }

  List<String> _generateSuggestions(double protein, double carbs, double fat,
      double progress, double balance) {
    final suggestions = <String>[];

    if (balance > 200) {
      suggestions.add(
          'Has superado tu objetivo calórico. Considera una comida más ligera.');
    } else if (balance < -200) {
      final remaining = balance.abs();
      suggestions.add(
          'Quedan ~${remaining.toInt()} kcal. Un snack saludable podría ayudarte.');
    }

    if (protein < 100) {
      suggestions.add(
          'Añade fuentes de proteína: pollo, pescado, huevos o legumbres.');
    }

    if (carbs > 300) {
      suggestions
          .add('Carbohidratos elevados. Prioriza carbohidratos complejos.');
    }

    if (fat > 80) {
      suggestions
          .add('Grasas elevadas. Reduce frituras y alimentos procesados.');
    }

    if (progress > 0.8 && progress < 1.0) {
      suggestions.add(
          'Casi llegas a tu objetivo. Última comida rica en proteína y fibra.');
    }

    return suggestions;
  }

  String _forecastDailyIntake(
      double consumed, double goal, FitnessMemoryProfile profile) {
    if (consumed > goal) {
      return 'Excederás tu objetivo. Considera reducir las próximas comidas.';
    }

    final remaining = goal - consumed;
    if (remaining > 500) {
      return 'Tienes espacio para meals completos. No tienes que restrictirte.';
    }

    return 'Estás cerca de tu objetivo. Opta por meals ligeros el resto del día.';
  }

  List<String> suggestAlternatives(FoodItemData currentFood) {
    final alternatives = <String>[];

    if (currentFood.calories > 400) {
      alternatives.add('Sustituto más ligero: Ensalada con pollo a la plancha');
      alternatives.add('Opción vegetariana: Tofu stir-fry');
    }

    if (currentFood.fat > 20) {
      alternatives
          .add('Versión baja en grasa: Pescado al horno en lugar de frito');
      alternatives
          .add('Reducir aceite: Usar spray en lugar de aceite abundante');
    }

    if (currentFood.protein < 10) {
      alternatives.add('Añadir proteína: Agregar claras de huevo o pollo');
      alternatives.add('Opción más proteica: Cambiar arroz por quinoa');
    }

    return alternatives.isEmpty
        ? ['Tu comida ya es equilibrada']
        : alternatives;
  }

  void weeklyHabitAnalysis() {
    // TODO: Implement weekly habit analysis based on profile.recentDays
  }

  double _calculateVariability(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    return variance > 0 ? (sqrt(variance) / mean) * 100 : 0;
  }

  void portionEstimationEnhancement() {
    // TODO: Implement portion estimation enhancement using vision models
  }

  List<String> _analyzeWeeklyHabits() {
    if (profile.recentDays.isEmpty) {
      return ['No hay datos suficientes para analizar hábitos semanales'];
    }

    final recent = profile.recentDays.take(7).toList();
    final habits = <String>[];

    final avgCal = recent.fold<double>(0, (s, d) => s + d.caloriesConsumed) /
        recent.length;
    final variability = _calculateVariability(
        recent.map((d) => d.caloriesConsumed.toDouble()).toList());

    if (variability > 20) {
      habits.add('Tu ingesta calórica es muy inconsistente durante la semana');
    } else {
      habits.add('Mantienes una ingesta calórica estable');
    }

    final highProteinDays = recent.where((d) => d.protein > 120).length;
    if (highProteinDays >= 5) {
      habits.add('Excelente consistencia en la ingesta de proteínas');
    } else if (highProteinDays < 3) {
      habits.add('Sueles descuidar la proteína en varios días de la semana');
    }

    return habits;
  }

  Map<String, double> _calculateRemainingNutrition(
      double protein, double carbs, double fat, double calorieGoal) {
    final targets = _getPersonalizedMacroTargets();

    return {
      'calories': (calorieGoal - (protein * 4 + carbs * 4 + fat * 9))
          .clamp(0, double.infinity),
      'protein': (calorieGoal * (targets['protein']! / 100) / 4 - protein)
          .clamp(0, double.infinity),
      'carbs': (calorieGoal * (targets['carbs']! / 100) / 4 - carbs)
          .clamp(0, double.infinity),
      'fat': (calorieGoal * (targets['fat']! / 100) / 9 - fat)
          .clamp(0, double.infinity),
    };
  }
}

class NutritionAnalysis {
  final double calorieProgress;
  final double calorieBalance;
  final bool isOverGoal;
  final MacroAnalysis macroAnalysis;
  final List<String> deficiencies;
  final List<String> suggestions;
  final String dailyForecast;
  final List<String> weeklyHabits;
  final Map<String, double> remainingNutrition;

  NutritionAnalysis({
    required this.calorieProgress,
    required this.calorieBalance,
    required this.isOverGoal,
    required this.macroAnalysis,
    required this.deficiencies,
    required this.suggestions,
    required this.dailyForecast,
    required this.weeklyHabits,
    required this.remainingNutrition,
  });
}

class MacroAnalysis {
  final double proteinPercentage;
  final double carbsPercentage;
  final double fatPercentage;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String status;
  final Map<String, double> personalizedTargets;
  final Map<String, double> deviationFromTargets;

  MacroAnalysis({
    required this.proteinPercentage,
    required this.carbsPercentage,
    required this.fatPercentage,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.status,
    required this.personalizedTargets,
    required this.deviationFromTargets,
  });
}

class FoodItemData {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  FoodItemData({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}
