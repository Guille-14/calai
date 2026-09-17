import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_lens/core/symmetry/macro_bridge.dart';
import 'package:calorie_lens/core/utils/date_key.dart';

/// MacroBridge es singleton: cada test parte de una tabla limpia
/// (mock de SharedPreferences vacío) y proteína diaria a cero.
void main() {
  final bridge = MacroBridge();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await bridge.resetDailyProtein();
    await bridge.setProteinGoal(120);
  });

  test('inicializa con 0 g de proteína y meta por defecto 120 g', () async {
    await bridge.initialize();
    expect(bridge.dailyProtein, 0);
    expect(bridge.proteinGoal, 120);
    expect(bridge.proteinProgress, 0);
    expect(bridge.metProteinGoal, isFalse);
  });

  test('multiplicador 1.0 por debajo de la meta y 1.2 al alcanzarla', () async {
    await bridge.initialize();

    expect(bridge.proteinMultiplier, 1.0);

    await bridge.addProtein(119.9);
    expect(bridge.dailyProtein, closeTo(119.9, 1e-9));
    expect(bridge.proteinMultiplier, 1.0);
    expect(bridge.metProteinGoal, isFalse);

    await bridge.addProtein(0.1);
    expect(bridge.dailyProtein, closeTo(120, 1e-9));
    expect(bridge.metProteinGoal, isTrue);
    expect(bridge.proteinMultiplier, 1.2);
    expect(bridge.proteinProgress, 1.0);
  });

  test('la clave de proteína del día usa formato YYYY-MM-DD con ceros', () async {
    await bridge.addProtein(30);

    final prefs = await SharedPreferences.getInstance();
    final expectedKey = 'daily_protein_${formatDateKey(DateTime.now())}';

    // La clave canónica (con ceros) es la que guarda el valor...
    expect(prefs.getDouble(expectedKey), closeTo(30, 1e-9));

    // ...y no debe existir ninguna clave legacy sin ceros.
    final today = DateTime.now();
    final legacyKey =
        'daily_protein_${today.year}-${today.month}-${today.day}';
    expect(prefs.containsKey(legacyKey), isFalse);
  });

  test('migración: una clave legacy sin ceros de HOY se mueve a la canónica',
      () async {
    final today = DateTime.now();
    final legacyKey =
        'daily_protein_${today.year}-${today.month}-${today.day}';
    SharedPreferences.setMockInitialValues({legacyKey: 45.0});

    await bridge.initialize();

    expect(bridge.dailyProtein, 45.0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(legacyKey), isFalse,
        reason: 'la clave legacy debe borrarse tras la migración');
    expect(
      prefs.getDouble('daily_protein_${formatDateKey(today)}'),
      45.0,
    );
  });

  test('getProteinStatusMessage devuelve un mensaje no vacío', () async {
    await bridge.initialize();
    expect(bridge.getProteinStatusMessage(), isNotEmpty);

    await bridge.addProtein(bridge.proteinGoal);
    expect(bridge.getProteinStatusMessage(), isNotEmpty);
  });

  test('syncFromFoodLog solo aplica si la fecha es hoy', () async {
    await bridge.initialize();

    // Una fecha anterior NO debe tocar la proteína de hoy.
    await bridge.syncFromFoodLog(
      totalProtein: 99,
      date: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(bridge.dailyProtein, 0);

    // Hoy SÍ.
    await bridge.syncFromFoodLog(
      totalProtein: 80,
      date: DateTime.now(),
    );
    expect(bridge.dailyProtein, 80);
  });
}
