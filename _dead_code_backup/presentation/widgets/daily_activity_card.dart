import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_constants.dart';
import '../../core/utils/app_translations.dart';

class DailyActivityCard extends StatefulWidget {
  const DailyActivityCard({super.key});

  @override
  State<DailyActivityCard> createState() => _DailyActivityCardState();
}

class _DailyActivityCardState extends State<DailyActivityCard> {
  int _caloriesBurned = 0;
  int _steps = 0;
  double _kilometers = 0.0;
  bool _isLoading = true;

  static const String _keyCalories = 'daily_calories_burned_';
  static const String _keySteps = 'daily_steps_';
  static const String _keyKm = 'daily_km_';

  String get _dateKey {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _dateKey;
    if (mounted) {
      setState(() {
        _caloriesBurned = prefs.getInt('$_keyCalories$dateKey') ?? 0;
        _steps = prefs.getInt('$_keySteps$dateKey') ?? 0;
        _kilometers = prefs.getDouble('$_keyKm$dateKey') ?? 0.0;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _dateKey;
    await prefs.setInt('$_keyCalories$dateKey', _caloriesBurned);
    await prefs.setInt('$_keySteps$dateKey', _steps);
    await prefs.setDouble('$_keyKm$dateKey', _kilometers);
  }

  void _showEditDialog({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required TextInputType keyboardType,
    required ValueChanged<String> onSave,
  }) {
    final controller = TextEditingController(text: value);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: AppColors.accentCalories),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: true,
          decoration: InputDecoration(
            suffixText: unit,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: AppColors.accentCalories),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: 140,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.surface.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.soft,
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentCalories.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions_run,
                      size: 20,
                      color: AppColors.accentCalories,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t.translate('daily_activity'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                _formatDate(DateTime.now()),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  icon: Icons.local_fire_department,
                  color: Colors.orange,
                  label: t.translate('calories'),
                  value: '$_caloriesBurned',
                  unit: 'kcal',
                  onTap: () => _showEditDialog(
                    icon: Icons.local_fire_department,
                    title: 'Calories Burned',
                    value: _caloriesBurned.toString(),
                    unit: 'kcal',
                    keyboardType: TextInputType.number,
                    onSave: (v) {
                      final n = int.tryParse(v) ?? 0;
                      setState(() => _caloriesBurned = n);
                      _saveData();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  icon: Icons.directions_walk,
                  color: Colors.green,
                  label: t.translate('steps'),
                  value: _formatNumber(_steps),
                  unit: '',
                  onTap: () => _showEditDialog(
                    icon: Icons.directions_walk,
                    title: 'Steps',
                    value: _steps.toString(),
                    unit: 'steps',
                    keyboardType: TextInputType.number,
                    onSave: (v) {
                      final n = int.tryParse(v) ?? 0;
                      setState(() => _steps = n);
                      _saveData();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  icon: Icons.straighten,
                  color: Colors.blue,
                  label: t.translate('distance'),
                  value: _kilometers.toStringAsFixed(1),
                  unit: 'km',
                  onTap: () => _showEditDialog(
                    icon: Icons.straighten,
                    title: 'Distance',
                    value: _kilometers.toString(),
                    unit: 'km',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onSave: (v) {
                      final n = double.tryParse(v) ?? 0.0;
                      setState(() => _kilometers = n);
                      _saveData();
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String unit,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              '$value${unit.isNotEmpty ? ' $unit' : ''}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  String _formatDate(DateTime date) {
    final t = AppTranslations.of(context);
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return t.translate('today_short');
    if (diff == 1) return t.translate('yesterday');
    return '${date.day}/${date.month}';
  }
}
