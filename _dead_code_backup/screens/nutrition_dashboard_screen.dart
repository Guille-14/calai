import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/health_context.dart';
import '../data/services/health_settings_service.dart';
import 'package:intl/intl.dart';

class NutritionDashboardScreen extends StatefulWidget {
  const NutritionDashboardScreen({super.key});

  @override
  State<NutritionDashboardScreen> createState() =>
      _NutritionDashboardScreenState();
}

class _NutritionDashboardScreenState extends State<NutritionDashboardScreen> {
  HealthContext? _healthContext;
  bool _isLoading = true;
  String _lastUpdate = '';

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final healthService =
          Provider.of<HealthSettingsService>(context, listen: false);
      final healthContext = await healthService.fetchTodayHealthContext();

      if (mounted) {
        setState(() {
          _healthContext = healthContext;
          _isLoading = false;
          _lastUpdate = DateFormat('HH:mm').format(DateTime.now());
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHealthData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Health metrics row
                  Row(
                    children: [
                      Expanded(
                        child: HealthStepsCard(
                          steps: _healthContext?.stepsToday ?? 0,
                          onTap: _loadHealthData,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CaloriesBurnedCard(
                          calories: _healthContext?.activeCaloriesToday ?? 0,
                          onTap: _loadHealthData,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Daily nutrition summary
                  const DailyNutritionSummaryCard(),

                  const SizedBox(height: 24),

                  // AI recommendation summary
                  AIRecommendationSummaryCard(caloriesBurned: _healthContext?.activeCaloriesToday ?? 0),

                  const SizedBox(height: 16),

                  // Last updated text
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Última actualización: $_lastUpdate',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class HealthStepsCard extends StatelessWidget {
  final int steps;
  final VoidCallback? onTap;

  const HealthStepsCard({
    super.key,
    required this.steps,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.8),
              Theme.of(context).primaryColor,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and title
            Row(
              children: [
                Icon(
                  Icons.directions_walk,
                  size: 28,
                  color: isDarkMode ? Colors.white : Colors.white,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Pasos Hoy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Steps count
            Text(
              steps.toString(),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Progress bar toward goal (10k steps)
            LayoutBuilder(
              builder: (context, constraints) {
                final double progress = (steps / 10000).clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: constraints.maxWidth * progress,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),

            // Goal text
            Text(
              '${(steps / 10000 * 100).toStringAsFixed(0)}% de 10,000 pasos',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CaloriesBurnedCard extends StatelessWidget {
  final double calories;
  final VoidCallback? onTap;

  const CaloriesBurnedCard({
    super.key,
    required this.calories,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.secondary.withOpacity(0.8),
              Theme.of(context).colorScheme.secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and title
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 28,
                  color: isDarkMode ? Colors.white : Colors.white,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Calorías Quemadas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calories count
            Text(
              '${calories.toStringAsFixed(0)} kcal',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Progress bar toward goal (500 kcal)
            LayoutBuilder(
              builder: (context, constraints) {
                final double progress = (calories / 500).clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: constraints.maxWidth * progress,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),

            // Goal text
            Text(
              '${(calories / 500 * 100).toStringAsFixed(0)}% de 500 kcal',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyNutritionSummaryCard extends StatelessWidget {

  const DailyNutritionSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 24,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              const Text(
                'Resumen Nutricional Diario',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nutrition facts
          
          Consumer<HealthSettingsService>(
            builder: (context, health, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NutrientItemLarge(
                    label: 'Calorías',
                    value: health.dailyCalories > 0 ? health.dailyCalories.toString() : '0',
                    unit: 'kcal',
                    icon: Icons.local_fire_department,
                  ),
                  _NutrientItemLarge(
                    label: 'Proteína',
                    value: health.dailyProtein > 0 ? health.dailyProtein.toStringAsFixed(0) : '0',
                    unit: 'g',
                    icon: Icons.fitness_center,
                  ),
                  _NutrientItemLarge(
                    label: 'Carbs',
                    value: health.dailyCarbs > 0 ? health.dailyCarbs.toStringAsFixed(0) : '0',
                    unit: 'g',
                    icon: Icons.bakery_dining,
                  ),
                  _NutrientItemLarge(
                    label: 'Grasa',
                    value: health.dailyFat > 0 ? health.dailyFat.toStringAsFixed(0) : '0',
                    unit: 'g',
                    icon: Icons.egg,
                  ),
                ],
              );
            }
          ),

        ],
      ),
    );
  }
}

class _NutrientItemLarge extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  const _NutrientItemLarge({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }
}

class AIRecommendationSummaryCard extends StatelessWidget {
  final double caloriesBurned;
  const AIRecommendationSummaryCard({super.key, this.caloriesBurned = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.tertiary.withOpacity(0.8),
            Theme.of(context).colorScheme.tertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.tertiary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.psychology_alt,
                size: 24,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              const Text(
                'Recomendaciones de IA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          
          // Recommendations
          Text(
            'Basado en tu actividad de hoy ( kcal):',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _buildDynamicMessage(),

        ],
      ),
    );
  }


  Widget _buildDynamicMessage() {
    if (caloriesBurned < 100) {
      return const Text('• Un buen comienzo, ¡sigue moviéndote!', style: TextStyle(color: Colors.white, fontSize: 14));
    } else if (caloriesBurned < 300) {
      return const Text('• ¡Buen trabajo! Has quemado el equivalente a una galleta grande (200 kcal).', style: TextStyle(color: Colors.white, fontSize: 14));
    } else if (caloriesBurned < 500) {
      return const Text('• ¡Genial! Has quemado el equivalente a un par de helados o un trozo de tarta (400 kcal).', style: TextStyle(color: Colors.white, fontSize: 14));
    } else if (caloriesBurned < 1000) {
      return const Text('• ¡Increíble! Has quemado el equivalente a una hamburguesa con queso (600+ kcal).', style: TextStyle(color: Colors.white, fontSize: 14));
    } else {
      return const Text('• ¡Modo Bestia! Has quemado más de 1000 kcal, el equivalente a una pizza entera. ¡Asegúrate de comer y descansar bien!', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold));
    }
  }

  bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}
