import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/preference_manager.dart';
import '../../data/models/user_data.dart';

class DailyTracker extends StatefulWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const DailyTracker({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  State<DailyTracker> createState() => _DailyTrackerState();
}

class _DailyTrackerState extends State<DailyTracker> {
  UserData? _cachedUserData;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_isInitialized && _cachedUserData != null) return;

    final prefs = await SharedPreferences.getInstance();
    final prefManager = PreferenceManager(prefs);
    _cachedUserData = prefManager.getUserData();
    _isInitialized = true;
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(DailyTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.calories != oldWidget.calories ||
        widget.protein != oldWidget.protein ||
        widget.carbs != oldWidget.carbs ||
        widget.fat != oldWidget.fat) {
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetCalories =
        _cachedUserData?.estimatedCalories.toDouble() ?? 2000.0;
    final remainingCalories =
        (targetCalories - widget.calories).clamp(0.0, targetCalories);
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CircularPercentIndicator(
            radius: 100.0,
            lineWidth: 20.0,
            percent: (widget.calories / targetCalories).clamp(0.0, 1.0),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  remainingCalories.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF000000),
                  ),
                ),
                const Text(
                  'restantes',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
            progressColor: primaryColor,
            backgroundColor: const Color(0xFFF5F5F7),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 800,
          ),
          const SizedBox(height: 32),
          _buildMacroRow(targetCalories),
        ],
      ),
    );
  }

  Widget _buildMacroRow(double targetCalories) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMacroPill(
          'Proteína',
          widget.protein,
          (_cachedUserData?.proteinGoal ?? 0).toDouble(),
          Colors.green,
        ),
        _buildMacroPill(
          'Grasas',
          widget.fat,
          (_cachedUserData?.fatGoal ?? 0).toDouble(),
          Colors.orange,
        ),
        _buildMacroPill(
          'Carbs',
          widget.carbs,
          (_cachedUserData?.carbsGoal ?? 0).toDouble(),
          Colors.amber,
        ),
      ],
    );
  }

  Widget _buildMacroPill(String label, double value, double goal, Color color) {
    final percent = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percent,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.toInt()}g',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF000000),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
