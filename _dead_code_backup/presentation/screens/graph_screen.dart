import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_constants.dart';
import '../../core/utils/app_translations.dart';
import '../cubit/food_log_cubit.dart';
import '../../data/local/preference_manager.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen>
    with TickerProviderStateMixin {
  DateTime? _selectedDate;
  int? _touchedGroupIndex;
  double _calorieGoal = 2000;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
    _loadCalorieGoal();
  }

  Future<void> _loadCalorieGoal() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    final prefs = PreferenceManager(sharedPrefs);
    final goal = prefs.getCalorieGoal();
    if (mounted && goal > 0) {
      setState(() {
        _calorieGoal = goal;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text(t.translate('weekly_summary'),
                style: const TextStyle(color: Colors.white)),
            if (_selectedDate != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedDate!.day}/${_selectedDate!.month}',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ],
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _showDatePicker,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<FoodLogCubit>().loadWeeklySummary();
          await _loadCalorieGoal();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: BlocBuilder<FoodLogCubit, FoodLogState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return SizedBox(
                    height: 400,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (_selectedDate != null) {
                  return _buildDailyView(context, state, _selectedDate!);
                }

                return Column(
                  children: [
                    _buildCalorieGoalCard(context),
                    SizedBox(height: 16),
                    _buildWeeklyChart(context, state),
                    SizedBox(height: 16),
                    _buildMacroSummary(context, state),
                    SizedBox(height: 16),
                    _buildWeeklyStats(context, state),
                    SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalorieGoalCard(BuildContext context) {
    final t = AppTranslations.of(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF667eea).withValues(alpha: 0.8),
            Color(0xFF764ba2).withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF667eea).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.flag, color: Colors.white, size: 32),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.translate('calorie_target'),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_calorieGoal.toInt()} ${t.translate('kcal')}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department,
                    color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  '${((_calculateWeeklyAvg() / _calorieGoal) * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateWeeklyAvg() {
    final cubit = context.read<FoodLogCubit>();
    final state = cubit.state;
    if (state.weeklyData.isEmpty) return 0;
    return state.weeklyData.reduce((a, b) => a + b) / state.weeklyData.length;
  }

  Widget _buildWeeklyChart(BuildContext context, FoodLogState state) {
    final t = AppTranslations.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.translate('weekly_summary'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  _buildLegend(),
                ],
              ),
              SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxY(state.weeklyData),
                    barGroups: state.weeklyData.asMap().entries.map((entry) {
                      final isTouched = entry.key == _touchedGroupIndex;
                      final isOverGoal = entry.value > _calorieGoal;
                      final isUnderGoal =
                          entry.value > 0 && entry.value < _calorieGoal * 0.5;

                      Color barColor;
                      if (isOverGoal) {
                        barColor = Colors.red.shade400;
                      } else if (isUnderGoal) {
                        barColor = Colors.orange.shade400;
                      } else {
                        barColor = Colors.green.shade400;
                      }

                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value * _animation.value,
                            width: isTouched ? 28 : 22,
                            fromY: 0,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                barColor.withValues(alpha: 0.8),
                                barColor,
                              ],
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: _calorieGoal,
                              color: Colors.grey.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          interval: _getMaxY(state.weeklyData) / 4,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final days = [
                              t.translate('mon'),
                              t.translate('tue'),
                              t.translate('wed'),
                              t.translate('thu'),
                              t.translate('fri'),
                              t.translate('sat'),
                              t.translate('sun'),
                            ];
                            final index = value.toInt();
                            if (index >= 0 && index < days.length) {
                              final isSelected = index == _touchedGroupIndex;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Color(0xFF667eea)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    days[index],
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Text('');
                          },
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _getMaxY(state.weeklyData) / 4,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: _calorieGoal,
                          color: Colors.orange.withValues(alpha: 0.7),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            labelResolver: (line) =>
                                t.translate('calorie_target'),
                          ),
                        ),
                      ],
                    ),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.blueGrey.shade800,
                        tooltipPadding: EdgeInsets.all(8),
                        tooltipMargin: 8,
                        tooltipRoundedRadius: 12,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final calories = rod.toY.toInt();
                          final isOver = calories > _calorieGoal;
                          final diff = calories - _calorieGoal;

                          return BarTooltipItem(
                            '$calories ${t.translate('kcal')}\n',
                            TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: isOver
                                    ? '+$diff ${t.translate('kcal')}'
                                    : '${_calorieGoal - calories} ${t.translate('remaining')}',
                                style: TextStyle(
                                  color: isOver
                                      ? Colors.red.shade300
                                      : Colors.green.shade300,
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      touchCallback: (event, response) {
                        setState(() {
                          if (response != null && response.spot != null) {
                            _touchedGroupIndex =
                                response.spot!.touchedBarGroupIndex;
                          } else {
                            _touchedGroupIndex = null;
                          }
                        });
                      },
                    ),
                  ),
                  duration: Duration(milliseconds: 300),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    final t = AppTranslations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendItem(Colors.green.shade400, t.translate('on_target')),
        SizedBox(width: 8),
        _buildLegendItem(Colors.red.shade400, t.translate('over')),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  double _getMaxY(List<double> data) {
    if (data.isEmpty) return _calorieGoal * 1.2;
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    return (maxValue > _calorieGoal ? maxValue : _calorieGoal) * 1.2;
  }

  Widget _buildMacroSummary(BuildContext context, FoodLogState state) {
    final t = AppTranslations.of(context);
    final total = state.totalProtein + state.totalCarbs + state.totalFat;
    if (total == 0) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.translate('daily_summary'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: state.totalProtein,
                          title:
                              '${((state.totalProtein / total) * 100).toInt()}%',
                          color: Colors.blue.shade400,
                          radius: 50,
                          titleStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: state.totalCarbs,
                          title:
                              '${((state.totalCarbs / total) * 100).toInt()}%',
                          color: Colors.orange.shade400,
                          radius: 50,
                          titleStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: state.totalFat,
                          title: '${((state.totalFat / total) * 100).toInt()}%',
                          color: Colors.purple.shade400,
                          radius: 50,
                          titleStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMacroLegend(
                      Colors.blue.shade400,
                      t.translate('protein'),
                      '${state.totalProtein.toInt()}g',
                    ),
                    SizedBox(height: 12),
                    _buildMacroLegend(
                      Colors.orange.shade400,
                      t.translate('carbs'),
                      '${state.totalCarbs.toInt()}g',
                    ),
                    SizedBox(height: 12),
                    _buildMacroLegend(
                      Colors.purple.shade400,
                      t.translate('fat'),
                      '${state.totalFat.toInt()}g',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroLegend(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyStats(BuildContext context, FoodLogState state) {
    final t = AppTranslations.of(context);
    final avgCalories = state.weeklyData.isEmpty
        ? 0.0
        : state.weeklyData.reduce((a, b) => a + b) / state.weeklyData.length;
    final maxCalories = state.weeklyData.isEmpty
        ? 0.0
        : state.weeklyData.reduce((a, b) => a > b ? a : b);
    final minCalories = state.weeklyData.isEmpty
        ? 0.0
        : state.weeklyData
            .where((e) => e > 0)
            .fold<double>(double.infinity, (a, b) => a < b ? a : b);
    final daysOnTarget = state.weeklyData
        .where((e) => e >= _calorieGoal * 0.9 && e <= _calorieGoal * 1.1)
        .length;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.translate('statistics'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '$daysOnTarget/7',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  Icons.analytics,
                  t.translate('average'),
                  '${avgCalories.toInt()} ${t.translate('kcal')}',
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  Icons.arrow_upward,
                  t.translate('highest'),
                  '${maxCalories.toInt()} ${t.translate('kcal')}',
                  Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  Icons.arrow_downward,
                  t.translate('lowest'),
                  minCalories == double.infinity
                      ? '0 ${t.translate('kcal')}'
                      : '${minCalories.toInt()} ${t.translate('kcal')}',
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  Icons.flag,
                  t.translate('on_target'),
                  '$daysOnTarget ${t.translate('days')}',
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF667eea),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      context.read<FoodLogCubit>().loadLogForDate(picked);
    }
  }

  Widget _buildDailyView(
      BuildContext context, FoodLogState state, DateTime date) {
    final t = AppTranslations.of(context);
    final isOverGoal = state.totalCalories > _calorieGoal;
    final remaining = _calorieGoal - state.totalCalories;

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedDate = null),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  t.translate('back_to_weekly'),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 24),
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isOverGoal
                  ? [Colors.red.shade400, Colors.red.shade600]
                  : [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (isOverGoal ? Colors.red : Color(0xFF667eea))
                    .withValues(alpha: 0.3),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                '${date.day} ${_getMonthName(date.month)} ${date.year}',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '${state.totalCalories.toInt()} ${t.translate('kcal')}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOverGoal
                      ? '+${remaining.abs().toInt()} ${t.translate('kcal')} ${t.translate('over')}'
                      : '${remaining.toInt()} ${t.translate('remaining')}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 16),
              LinearProgressIndicator(
                value: (state.totalCalories / _calorieGoal).clamp(0.0, 1.5),
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverGoal ? Colors.red.shade200 : Colors.white,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        if (state.meals.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              t.translate('meals'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 12),
          ...state.meals.map((meal) => Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.fastfood, color: Colors.orange),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${meal.quantity.toInt()}g • ${meal.calories.toInt()} kcal',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              )),
        ] else ...[
          Container(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.no_meals, size: 64, color: Colors.grey[300]),
                SizedBox(height: 16),
                Text(
                  t.translate('no_meals_recorded'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getMonthName(int month) {
    final t = AppTranslations.of(context);
    const monthKeys = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec'
    ];
    return t.translate(monthKeys[month - 1]);
  }
}
