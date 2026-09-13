import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/preference_manager.dart';
import '../../data/services/google_fit_service.dart';
import '../../data/services/image_storage_service.dart';
import '../cubit/food_log_cubit.dart';
import 'scan_food_screen.dart';
import 'nutritional_chat_screen.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fitService = GoogleFitService.instance;
  bool _isFitConnected = false;
  final int _waterGoal = 8;

  // Metas por defecto; se sobreescriben con el perfil del onboarding si existe.
  int _calorieGoal = 2570;
  int _proteinGoal = 161;
  int _carbsGoal = 321;
  int _fatGoal = 71;

  int _steps = 0;
  int _kcalBurned = 0;
  bool _isSyncing = false;
  String _lastSync = 'Sincronizar ahora';

  @override
  void initState() {
    super.initState();
    // Health Connect se toca DESPUÉS del primer frame: si el plugin nativo
    // falla, la pantalla ya está dibujada y la app no muere en arranque.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkFitStatus();
      _syncHealthData();
    });
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData =
          PreferenceManager(prefs).getUserData();
      if (userData != null && mounted) {
        setState(() {
          if (userData.estimatedCalories > 0) {
            _calorieGoal = userData.estimatedCalories;
          }
          if (userData.proteinGoal > 0) _proteinGoal = userData.proteinGoal;
          if (userData.carbsGoal > 0) _carbsGoal = userData.carbsGoal;
          if (userData.fatGoal > 0) _fatGoal = userData.fatGoal;
        });
      }
    } catch (_) {
      // Se mantienen los valores por defecto
    }
  }

  Future<void> _checkFitStatus() async {
    final connected = await _fitService.checkAuthorization();
    if (mounted) setState(() => _isFitConnected = connected);
  }

  Future<void> _syncHealthData() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    final data = await _fitService.fetchDailyData();

    if (mounted) {
      setState(() {
        if (!data.hasError) {
          _steps = data.steps;
          _kcalBurned = data.activeCalories;
          _isFitConnected = true;
          _lastSync = 'Actualizado hace un momento';
        } else {
          _lastSync = 'Error de conexión';
        }
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      drawer: const AppDrawer(),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: BlocBuilder<FoodLogCubit, FoodLogState>(
          builder: (context, foodState) {
            return RefreshIndicator(
              onRefresh: _syncHealthData,
              backgroundColor: Theme.of(context).colorScheme.surface,
              color: Theme.of(context).colorScheme.primary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildHealthConnectCard(),
                    const SizedBox(height: 16),
                    _buildWaterCard(foodState.waterGlasses),
                    const SizedBox(height: 16),
                    _buildGoalsCard(foodState),
                    if (foodState.meals.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildMealsSection(foodState),
                    ] else ...[
                      const SizedBox(height: 24),
                      _buildEmptyMealsState(),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NutritionalChatScreen()));
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.black),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Builder(
        builder: (BuildContext context) {
          return IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () { Scaffold.of(context).openDrawer(); },
          );
        },
      ),
      title: const Text('CalAI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      centerTitle: false,
    );
  }

  Widget _buildHealthConnectCard() {
    return GestureDetector(
      onTap: _syncHealthData,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Health Connect',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(_isSyncing ? 'Sincronizando...' : _lastSync,
                          style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: _isFitConnected ? Colors.green : Colors.grey,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(_isFitConnected ? 'Connected' : 'Offline',
                          style: const TextStyle(color: Colors.white, fontSize: 8)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildHealthStat('Pasos', '$_steps', '10000', Icons.show_chart)),
                const SizedBox(width: 16),
                Expanded(child: _buildHealthStat('Kcal', '$_kcalBurned', '500', Icons.local_fire_department)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStat(String label, String value, String goal, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white60, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              TextSpan(text: ' / $goal', style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: double.tryParse(value) != null ? double.parse(value) / double.parse(goal) : 0,
          backgroundColor: Colors.white10,
          valueColor: const AlwaysStoppedAnimation(Colors.white),
          minHeight: 2,
        )
      ],
    );
  }

  /// Usa el estado persistente del cubit (water_glasses_YYYY-MM-DD).
  /// Antes era estado local que se perdía al cerrar la app, en paralelo al
  /// sistema persistente del cubit que nadie usaba.
  Widget _buildWaterCard(int waterGlasses) {
    final cubit = context.read<FoodLogCubit>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondary,
            Theme.of(context).colorScheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Consumo de Agua', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                child: Text('$waterGlasses/$_waterGoal', style: const TextStyle(color: Colors.white, fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildWaterBtn(Icons.remove, () => cubit.removeWaterGlass()),
              const SizedBox(width: 32),
              Column(
                children: [
                  Text('${(waterGlasses * 0.25).toStringAsFixed(2)}L',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const Text('de 2.00L', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
              const SizedBox(width: 32),
              _buildWaterBtn(Icons.add, () => cubit.addWaterGlass()),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: waterGlasses / _waterGoal,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            minHeight: 4,
          )
        ],
      ),
    );
  }

  Widget _buildWaterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildGoalsCard(FoodLogState state) {
    final calorieGoal = _calorieGoal;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Objetivos Diarios', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  Text('${state.totalCalories.toInt()} / $calorieGoal kcal', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  CircularPercentIndicator(
                    radius: 50.0,
                    lineWidth: 8.0,
                    percent: (state.totalCalories / calorieGoal).clamp(0, 1),
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${state.totalCalories.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Text('KCAL', style: TextStyle(fontSize: 8, color: Colors.white54)),
                      ],
                    ),
                    circularStrokeCap: CircularStrokeCap.round,
                    backgroundColor: Colors.white10,
                    progressColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Column(
                      children: [
                        _buildMacroRow('Proteína', '${state.totalProtein.toInt()}/$_proteinGoal g', Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        _buildMacroRow('Carbohidratos', '${state.totalCarbs.toInt()}/$_carbsGoal g', Theme.of(context).colorScheme.secondary),
                        const SizedBox(height: 16),
                        _buildMacroRow('Grasa', '${state.totalFat.toInt()}/$_fatGoal g', Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanFoodScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Escanear Comida', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  /// Estado vacío con llamada a la acción: guía al usuario nuevo
  /// en lugar de mostrar simplemente "no hay comidas".
  Widget _buildEmptyMealsState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.restaurant_menu, color: Theme.of(context).colorScheme.primary, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aún no has registrado nada hoy',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Haz una foto de tu plato y la IA calculará las calorías y macros por ti.',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanFoodScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.camera_alt, size: 20),
              label: const Text('Escanear mi primera comida', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsSection(FoodLogState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Comidas de Hoy', style: TextStyle(// la ruta correcta es image_storage_service.dart
                                                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${state.meals.length} elementos', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        ...state.meals.map((meal) => _buildMealCard(meal)),
      ],
    );
  }

  // Caché de futures de imagen: evita releer del disco en cada rebuild.
  final Map<String, Future<File?>> _imageFutures = {};

  Widget _buildMealCard(dynamic meal) {
    final imageService = ImageStorageService();
    return GestureDetector(
      onTap: () => _showMealDetails(meal),
      onLongPress: () => _showDeleteMealDialog(meal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Builder(
              builder: (context) {
                final url = meal.imageUrl as String?;
                Future<File?>? imageFuture;
                if (url != null && url.isNotEmpty) {
                  imageFuture = _imageFutures.putIfAbsent(
                      url, () => imageService.getFoodImage(url));
                }
                return FutureBuilder<File?>(
                  future: imageFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(snapshot.data!, width: 60, height: 60, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildDefaultImage()),
                      );
                    }
                    return _buildDefaultImage();
                  },
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.name ?? 'Comida', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${meal.calories.toInt()} kcal • ${meal.protein.toInt()}g P • ${meal.carbs.toInt()}g C • ${meal.fat.toInt()}g G', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            // Borrado visible y directo (el long-press seguía existiendo pero
            // era indescubrible); con Deshacer en el SnackBar.
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
              tooltip: 'Eliminar',
              onPressed: () => _deleteMealWithUndo(meal),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.restaurant, color: Colors.white38),
    );
  }

  void _showMealDetails(dynamic meal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
       builder: (ctx) => Container(
         decoration: const BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
         padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(meal.name ?? 'Comida', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildMacroDetailRow('Calorías', '${meal.calories.toInt()}', 'kcal', AppColors.caloriesColor),
            const Divider(color: Colors.white12, height: 32),
            _buildMacroDetailRow('Proteína', '${meal.protein.toInt()}', 'g', Colors.green),
            _buildMacroDetailRow('Carbohidratos', '${meal.carbs.toInt()}', 'g', Colors.blue),
            _buildMacroDetailRow('Grasa', '${meal.fat.toInt()}', 'g', Colors.orange),
            if (meal.quantity != null) ...[
              const Divider(color: Colors.white12, height: 32),
              _buildMacroDetailRow('Cantidad', '${meal.quantity.toInt()}', meal.unit?.toString().split('.').last ?? 'g', Colors.white54),
            ],
            if (meal.confidenceScore != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (meal.confidenceScore > 0.7 ? Colors.green : Colors.orange).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Confianza: ${(meal.confidenceScore * 100).toInt()}%',
                    style: TextStyle(color: meal.confidenceScore > 0.7 ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _showDeleteMealDialog(meal); },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2), foregroundColor: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.check),
                    label: const Text('Cerrar'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryAccent, foregroundColor: Colors.black),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroDetailRow(String label, String value, String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14))),
          Text('$value $unit', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Borra la comida y ofrece DESHACER desde el SnackBar durante 5 s.
  /// Flujo más cómodo que el diálogo de confirmación: una acción menos
  /// para eliminar, y el error es reversible.
  void _deleteMealWithUndo(dynamic meal) {
    HapticFeedback.mediumImpact();
    context.read<FoodLogCubit>().deleteMeal(meal);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${meal.name ?? 'Comida'}" eliminada',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C2C2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: Theme.of(context).colorScheme.primary,
          onPressed: () {
            context.read<FoodLogCubit>().addMeal(meal);
          },
        ),
      ),
    );
  }

  void _showDeleteMealDialog(dynamic meal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Eliminar Comida', style: TextStyle(color: Colors.white)),
        content: Text('¿Estás seguro de eliminar "${meal.name}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () { Navigator.pop(ctx); _deleteMealWithUndo(meal); }, child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, String value, Color color) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
