import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_constants.dart';
import '../../core/utils/app_translations.dart';
import '../../data/local/preference_manager.dart';
import '../../data/models/food_item.dart';
import '../../data/models/health_data.dart';
import '../../data/services/google_fit_service.dart';
import '../cubit/food_log_cubit.dart';
import '../widgets/macro_card.dart';
import '../widgets/food_card.dart';
import '../widgets/water_intake_card.dart';
import '../widgets/health_card.dart';
import '../widgets/popups.dart';
import 'scan_food_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final Set<String> _animatedFoodIds = {};

  HealthData _healthData = HealthData.empty();
  bool _isGoogleFitConnected = false;
  bool _isGoogleFitLoading = false;

  int _caloriesGoal = 2100;
  int _proteinGoal = 150;
  int _carbsGoal = 250;
  int _fatGoal = 65;

  @override
  void initState() {
    super.initState();
    _loadUserGoals();
    _checkGoogleFitConnection();
  }

  Future<void> _loadUserGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final prefManager = PreferenceManager(prefs);
    if (mounted) {
      setState(() {
        _caloriesGoal = prefManager.getCalorieGoal().toInt();
        _proteinGoal = prefManager.getProteinGoal();
        _carbsGoal = prefManager.getCarbsGoal();
        _fatGoal = prefManager.getFatGoal();
      });
    }
  }

  Future<void> _checkGoogleFitConnection() async {
    final service = GoogleFitService.instance;
    final connected = await service.checkAuthorization();
    if (connected) {
      setState(() {
        _isGoogleFitConnected = true;
      });
      _refreshGoogleFitData();
    }
  }

  Future<void> _connectGoogleFit() async {
    setState(() {
      _isGoogleFitLoading = true;
    });

    final service = GoogleFitService.instance;
    final success = await service.requestAuthorization();

    if (success && mounted) {
      setState(() {
        _isGoogleFitConnected = true;
        _isGoogleFitLoading = false;
      });
      _refreshGoogleFitData();
    } else if (mounted) {
      setState(() {
        _isGoogleFitLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No se pudo conectar con Google Fit. Asegúrate de tener la app instalada.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _refreshGoogleFitData() async {
    if (!_isGoogleFitConnected) return;

    setState(() {
      _isGoogleFitLoading = true;
    });

    final service = GoogleFitService.instance;
    final data = await service.fetchDailyData();

    if (mounted) {
      if (data.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data.error ?? 'Error al obtener datos',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      } else {
        setState(() {
          _healthData = HealthData(
            steps: data.steps,
            stepsGoal: _healthData.stepsGoal,
            activeCalories: data.activeCalories,
            activeCaloriesGoal: _healthData.activeCaloriesGoal,
            distanceKm: data.distanceKm,
            distanceGoalKm: _healthData.distanceGoalKm,
            deviceName: data.deviceName,
            lastSync: data.lastSync,
          );
          _isGoogleFitLoading = false;
        });
      }
    }
  }

  Future<void> _showDebugInfo() async {
    if (!_isGoogleFitConnected) return;

    final service = GoogleFitService.instance;
    final installed = await service.isHealthConnectInstalled();
    final auth = await service.checkAuthorization();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Health Connect Debug'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Health Connect instalado: ${installed ? "Sí" : "No"}'),
              const SizedBox(height: 8),
              Text('Autorizado: ${auth ? "Sí" : "No"}'),
              const SizedBox(height: 8),
              Text('Pasos: ${_healthData.steps}'),
              Text('Calorías: ${_healthData.activeCalories}'),
              Text(
                  'Distancia: ${_healthData.distanceKm.toStringAsFixed(2)} km'),
              const SizedBox(height: 8),
              const Text(
                'Si los pasos salen pero no calorías/distancia, '
                'Zepp Life no está escribiendo esos datos en Health Connect. '
                'Revisa en la app Health Connect → Permisos de apps → Zepp Life.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<FoodLogCubit, FoodLogState>(
          listener: (context, state) {
            if (state.successMessage != null &&
                state.successMessage!.contains('detected successfully') &&
                state.meals.isNotEmpty) {
              final lastMeal = state.meals.last;
              if (!_animatedFoodIds.contains(lastMeal.id)) {
                _animatedFoodIds.add(lastMeal.id);
                FoodAddedPopup.show(
                  context,
                  foodName: lastMeal.name,
                  calories: lastMeal.calories.toInt(),
                );
              }
            }
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: Colors.red,
                ),
              );
              context.read<FoodLogCubit>().clearMessages();
            }
          },
          builder: (context, state) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: HealthCard(
                      healthData: _healthData,
                      isConnected: _isGoogleFitConnected,
                      isLoading: _isGoogleFitLoading,
                      onConnectTap:
                          _isGoogleFitConnected ? null : _connectGoogleFit,
                      onRefreshTap: _refreshGoogleFitData,
                      onDebugTap: _showDebugInfo,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const SliverToBoxAdapter(child: WaterIntakeCard()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(child: _buildMacroSection(state)),
                SliverToBoxAdapter(child: _buildMealsSection(state)),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final t = AppTranslations.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.translate('hello_user')} 👋',
                  style: AppTextStyles.heading1,
                ),
                const SizedBox(height: 4),
                Text(
                  _getGreeting(context),
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.soft,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: AppColors.accentCalories.withValues(alpha: 0.2),
                child: const Icon(
                  Icons.person,
                  color: AppColors.accentCalories,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroSection(FoodLogState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: MacroCard(
        caloriesConsumed: state.totalCalories,
        caloriesGoal: _caloriesGoal.toDouble(),
        proteinConsumed: state.totalProtein,
        proteinGoal: _proteinGoal.toDouble(),
        carbsConsumed: state.totalCarbs,
        carbsGoal: _carbsGoal.toDouble(),
        fatConsumed: state.totalFat,
        fatGoal: _fatGoal.toDouble(),
      ),
    );
  }

  Widget _buildMealsSection(FoodLogState state) {
    final t = AppTranslations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.translate('todays_meals'),
                style: AppTextStyles.heading3,
              ),
              if (state.meals.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentCalories.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.meals.length}',
                    style: TextStyle(
                      color: AppColors.accentCalories,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (state.meals.isEmpty)
          _buildEmptyState()
        else
          ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.meals.length,
            itemBuilder: (context, index) {
              final meal = state.meals[state.meals.length - 1 - index];
              final showAnimation = _animatedFoodIds.contains(meal.id);

              return FoodCard(
                food: meal,
                showAnimation: showAnimation,
                onTap: () => _showMealDetail(context, meal),
                onDelete: () => _deleteMeal(context, meal),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final t = AppTranslations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.primary),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accentCalories.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              size: 40,
              color: AppColors.accentCalories,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.translate('no_meals'),
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            t.translate('no_meals_tap_scan'),
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentCalories.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ScanFoodScreen(),
            fullscreenDialog: true,
          ),
        ),
        backgroundColor: AppColors.accentCalories,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
        icon: const Icon(Icons.camera_alt, size: 24),
        label: Text(
          AppTranslations.of(context).translate('scan_food'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _showMealDetail(BuildContext context, FoodItem meal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MealDetailSheet(meal: meal),
      ),
    );
  }

  void _deleteMeal(BuildContext context, FoodItem meal) {
    final t = AppTranslations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.translate('delete_meal')),
        content: Text(t.translate('delete_meal_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<FoodLogCubit>().deleteMeal(meal);
            },
            child: Text(t.translate('delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getGreeting(BuildContext context) {
    final t = AppTranslations.of(context);
    final hour = DateTime.now().hour;
    if (hour < 12) return t.translate('good_morning');
    if (hour < 17) return t.translate('good_afternoon');
    return t.translate('good_evening');
  }
}

class _MealDetailSheet extends StatelessWidget {
  final FoodItem meal;

  const _MealDetailSheet({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meal.imageUrl != null)
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.primary),
                  boxShadow: AppShadows.card,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.primary),
                  child: Image.file(
                    File(meal.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(meal.name, style: AppTextStyles.heading1),
            const SizedBox(height: 8),
            Text(
              '${meal.quantity.toInt()}g • ${meal.calories.toInt()} kcal',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 32),
            _buildMacroDetail('Protein', meal.protein, AppColors.accentProtein),
            _buildMacroDetail('Carbs', meal.carbs, AppColors.accentCarbs),
            _buildMacroDetail('Fat', meal.fat, AppColors.accentFat),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroDetail(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Text(label, style: AppTextStyles.bodyLarge),
          const Spacer(),
          Text(
            '${value.toStringAsFixed(1)}g',
            style: AppTextStyles.heading3.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
