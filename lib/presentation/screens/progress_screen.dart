import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_constants.dart';
import '../cubit/food_log_cubit.dart';
import '../../data/local/preference_manager.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/services/image_storage_service.dart';
import '../../data/models/food_item.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with TickerProviderStateMixin {
  DateTime _focusedMonth = DateTime.now();
  double _calorieGoal = 2000;
  late AnimationController _animationController;
  late Animation<double> _animation;
  Map<DateTime, List<FoodItem>> _monthFoodData = {};
  Map<DateTime, double> _weeklyTotals = {};
  List<FoodItem> _recentMeals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutCubic);
    _animationController.forward();
    _loadData();
  }

  Future<void> _loadData() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    final prefs = PreferenceManager(sharedPrefs);
    final goal = prefs.getCalorieGoal();

    await _loadMonthData();
    await _loadWeeklyTotals();
    await _loadRecentMeals();

    if (mounted) {
      setState(() {
        _calorieGoal = goal > 0 ? goal : 2000;
        _isLoading = false;
      });
    }
  }

  FoodRepository get _repository => context.read<FoodLogCubit>().repository;

  /// Mes visible en UNA sola consulta SQL indexada por timestamp
  /// (antes: ~30 lecturas de SharedPreferences día a día).
  Future<void> _loadMonthData() async {
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final monthEnd =
        DateTime(_focusedMonth.year, _focusedMonth.month, daysInMonth);

    final meals = await _repository.getFoodLogForRange(monthStart, monthEnd);

    final Map<DateTime, List<FoodItem>> monthData = {};
    for (final meal in meals) {
      final dayKey = DateTime(
          meal.timestamp.year, meal.timestamp.month, meal.timestamp.day);
      monthData.putIfAbsent(dayKey, () => []).add(meal);
    }

    _monthFoodData = monthData;
  }

  /// Totales de los últimos 7 días con una consulta de rango única
  /// (antes: 7 lecturas de SharedPreferences; el gráfico anterior usaba
  /// `_monthFoodData`, que solo cubría el mes visible, así que los días de
  /// la semana que caían en el mes anterior mostraban 0 kcal).
  Future<void> _loadWeeklyTotals() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    final meals = await _repository.getFoodLogForRange(weekStart, today);

    final Map<DateTime, double> totals = {};
    for (final meal in meals) {
      final dayKey = DateTime(
          meal.timestamp.year, meal.timestamp.month, meal.timestamp.day);
      totals[dayKey] = (totals[dayKey] ?? 0) + meal.calories;
    }
    // Los días sin datos aparecen explícitos en 0 para el gráfico.
    for (int i = 6; i >= 0; i--) {
      final dayKey = today.subtract(Duration(days: i));
      totals.putIfAbsent(dayKey, () => 0.0);
    }

    _weeklyTotals = totals;
  }

  /// Las 20 comidas más recientes con una consulta LIMIT indexada
  /// (antes: bucle de 30 días sobre SharedPreferences).
  Future<void> _loadRecentMeals() async {
    _recentMeals = await _repository.getRecentFoodEntries(20);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Progreso',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: _showFullCalendar,
          ),
        ],
      ),
      body: BlocBuilder<FoodLogCubit, FoodLogState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.accentCalories,
            backgroundColor: const Color(0xFF111111),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildWeeklyChart(),
                  const SizedBox(height: 16),
                  _buildSummaryCards(),
                  const SizedBox(height: 16),
                  _buildRecentMealsList(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<double> chartData = [];

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      chartData.add(_weeklyTotals[date] ?? 0.0);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Resumen Semanal',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.accentCalories.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${_calorieGoal.toInt()} kcal',
                    style: const TextStyle(
                        color: AppColors.accentCalories,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: _calorieGoal * 1.5,
                barGroups: chartData.asMap().entries.map((entry) {
                  final isToday = entry.key == 6;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value,
                        color: entry.value > _calorieGoal
                            ? Colors.red
                            : (isToday
                                ? AppColors.accentCalories
                                : Colors.white38),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: _calorieGoal * 1.5,
                          color: Colors.white.withValues(alpha: 0.03),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                        final today = DateTime.now();
                        final targetDate =
                            today.subtract(Duration(days: 6 - value.toInt()));
                        final isToday = targetDate.day == today.day &&
                            targetDate.month == today.month;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(days[value.toInt() % 7],
                              style: TextStyle(
                                  color: isToday
                                      ? AppColors.accentCalories
                                      : Colors.white24,
                                  fontSize: 11,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == _calorieGoal) {
                          return const SizedBox.shrink();
                        }
                        return Text('${value.toInt()}',
                            style: const TextStyle(
                                color: Colors.white24, fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calorieGoal,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: value == _calorieGoal
                        ? Colors.green.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.03),
                    strokeWidth: value == _calorieGoal ? 1 : 0.5,
                    dashArray: value == _calorieGoal ? [5, 5] : null,
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                        y: _calorieGoal,
                        color: Colors.green.withValues(alpha: 0.5),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                            show: true,
                            labelResolver: (_) => 'Objetivo',
                            style: const TextStyle(
                                color: Colors.green, fontSize: 10))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final todayMeals = _monthFoodData[todayKey] ?? [];
    final todayCalories = todayMeals.fold(0.0, (sum, m) => sum + m.calories);
    final todayProtein = todayMeals.fold(0.0, (sum, m) => sum + m.protein);
    final todayCarbs = todayMeals.fold(0.0, (sum, m) => sum + m.carbs);
    final todayFat = todayMeals.fold(0.0, (sum, m) => sum + m.fat);

    final daysWithMeals =
        _monthFoodData.entries.where((e) => e.value.isNotEmpty).length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildSummaryCard('Hoy', '${todayCalories.toInt()} kcal',
                    AppColors.accentCalories, Icons.local_fire_department)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildSummaryCard('Comidas', '${todayMeals.length}',
                    AppColors.accentCarbs, Icons.restaurant)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildMacroCard(
                    'Proteína', '${todayProtein.toInt()}g', Colors.green)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildMacroCard(
                    'Carbs', '${todayCarbs.toInt()}g', Colors.blue)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildMacroCard(
                    'Grasa', '${todayFat.toInt()}g', Colors.orange)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildSummaryCard('Días Registrados', '$daysWithMeals',
                    Colors.purple, Icons.calendar_today)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildSummaryCard(
                    'Promedio',
                    '${_calculateAverage()} kcal',
                    Colors.cyan,
                    Icons.analytics)),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  int _calculateAverage() {
    if (_monthFoodData.isEmpty) return 0;
    final daysWithData =
        _monthFoodData.entries.where((e) => e.value.isNotEmpty).toList();
    if (daysWithData.isEmpty) return 0;

    double total = 0;
    for (final entry in daysWithData) {
      total += entry.value.fold(0.0, (sum, m) => sum + m.calories);
    }
    return (total / daysWithData.length).round();
  }

  Widget _buildRecentMealsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Comidas Recientes',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_recentMeals.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.restaurant_outlined,
                      color: Colors.white24, size: 40),
                  SizedBox(height: 8),
                  Text('No hay comidas registradas',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          )
        else
          ..._recentMeals.map((meal) => _buildMealCard(meal)),
      ],
    );
  }

  // Caché de futures de imagen: evita releer del disco en cada rebuild.
  final Map<String, Future<File?>> _imageFutures = {};

  Widget _buildMealCard(FoodItem meal) {
    final imageService = ImageStorageService();
    final dateStr = '${meal.timestamp.day}/${meal.timestamp.month}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              final url = meal.imageUrl;
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
                      child: Image.file(snapshot.data!,
                          width: 56, height: 56, fit: BoxFit.cover),
                    );
                  }
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.restaurant, color: Colors.white38),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(meal.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(dateStr,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    '${meal.calories.toInt()} kcal • ${meal.protein.toInt()}g P • ${meal.carbs.toInt()}g C • ${meal.fat.toInt()}g G',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullCalendar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) => Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white12))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context)),
                    const Text('Calendario',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left,
                              color: Colors.white),
                          onPressed: () {
                            setSheetState(() {
                              _focusedMonth = DateTime(
                                  _focusedMonth.year, _focusedMonth.month - 1);
                            });
                            _loadMonthData();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right,
                              color: Colors.white),
                          onPressed: () {
                            setSheetState(() {
                              _focusedMonth = DateTime(
                                  _focusedMonth.year, _focusedMonth.month + 1);
                            });
                            _loadMonthData();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _monthFoodData.length,
                  itemBuilder: (context, index) {
                    final entry = _monthFoodData.entries.elementAt(index);
                    final date = entry.key;
                    final meals = entry.value;
                    final totalCalories =
                        meals.fold(0.0, (sum, m) => sum + m.calories);

                    return ExpansionTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: totalCalories > _calorieGoal
                              ? Colors.red.withValues(alpha: 0.2)
                              : (totalCalories > 0
                                  ? AppColors.accentCalories.withValues(alpha: 0.2)
                                  : Colors.white10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                            child: Text('${date.day}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))),
                      ),
                      title: Text('${date.day}/${date.month}/${date.year}',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        meals.isEmpty
                            ? 'Sin registrar'
                            : '${totalCalories.toInt()} kcal • ${meals.length} ${meals.length == 1 ? 'comida' : 'comidas'}',
                        style: TextStyle(
                            color: meals.isEmpty
                                ? Colors.white38
                                : Colors.white54),
                      ),
                      children: meals.isEmpty
                          ? [
                              const ListTile(
                                  title: Text('No hay comidas registradas',
                                      style: TextStyle(color: Colors.white54)))
                            ]
                          : meals
                              .map((meal) => ListTile(
                                    leading: const Icon(Icons.restaurant,
                                        color: Colors.white38),
                                    title: Text(meal.name,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    trailing: Text(
                                        '${meal.calories.toInt()} kcal',
                                        style: const TextStyle(
                                            color: Colors.white54)),
                                  ))
                              .toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
