/// Feedback de entrenamiento -> nutrición (la fusión CalAI + Symmetry).
///
/// Toggle "Creditar calorías quemadas": cuando está ACTIVO, las calorías
/// estimadas de cada entrenamiento completado se restan del objetivo
/// diario. DEFAULT OFF: el usuario debe activarlo explícitamente en
/// Perfil (no se asume que quiera restar calorías de su dieta).
const String kCreditWorkoutCaloriesKey = 'credit_workout_calories';

/// Pref por día con el total (kcal) ya creditado:
/// 'calorie_adjustment_YYYY-MM-DD' (usa formatDateKey).
const String kCalorieAdjustmentKeyPrefix = 'calorie_adjustment_';

/// Estima las calorías quemadas en un entrenamiento con la fórmula MET:
/// kcal = MET × 3.5 × pesoKg / 200 × minutos.
///
/// MET 5 ≈ entrenamiento de fuerza de intensidad moderada-alta.
/// [weightKg] por defecto 75 (fallback si el perfil no tiene peso).
double estimateWorkoutCalories({required int minutes, double weightKg = 75}) {
  if (minutes <= 0) return 0;
  final kg = weightKg > 0 ? weightKg : 75.0;
  return 5.0 * 3.5 * kg / 200.0 * minutes;
}
