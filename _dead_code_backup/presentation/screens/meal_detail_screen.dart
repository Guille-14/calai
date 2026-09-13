import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/app_translations.dart';
import '../../data/models/food_item.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../cubit/food_log_cubit.dart';
import 'edit_meal_screen.dart';

class MealDetailScreen extends StatefulWidget {
  final FoodItem meal;

  const MealDetailScreen({
    super.key,
    required this.meal,
  });

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  late FoodItem _currentMeal;

  @override
  void initState() {
    super.initState();
    _currentMeal = widget.meal;
  }

  void _deleteMeal(BuildContext context) {
    final t = AppTranslations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate('delete')),
        content: Text(t.translate('are_you_sure_delete_meal')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              context.read<FoodLogCubit>().deleteMeal(_currentMeal);
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: Text(t.translate('delete'),
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editMeal(BuildContext context) async {
    final result = await Navigator.push<FoodItem>(
      context,
      MaterialPageRoute(
        builder: (context) => EditMealScreen(meal: _currentMeal),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _currentMeal = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentMeal.name,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => _editMeal(context),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteMeal(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentMeal.imageUrl != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    _currentMeal.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      height: 200,
                      color: const Color(0xFF2C2C2E),
                      child: const Icon(Icons.fastfood,
                          size: 64, color: Colors.white38),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              t.translate('details'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DetailListItem(
              icon: Icons.local_fire_department,
              label: t.translate('calories'),
              value:
                  '${_currentMeal.calories.toStringAsFixed(1)} ${t.translate('kcal')}',
            ),
            DetailListItem(
              icon: Icons.fitness_center,
              label: t.translate('protein'),
              value:
                  '${_currentMeal.protein.toStringAsFixed(1)} ${t.translate('grams')}',
            ),
            DetailListItem(
              icon: Icons.grain,
              label: t.translate('carbs'),
              value:
                  '${_currentMeal.carbs.toStringAsFixed(1)} ${t.translate('grams')}',
            ),
            DetailListItem(
              icon: Icons.oil_barrel,
              label: t.translate('fat'),
              value:
                  '${_currentMeal.fat.toStringAsFixed(1)} ${t.translate('grams')}',
            ),
            DetailListItem(
              icon: Icons.scale,
              label: t.translate('quantity'),
              value:
                  '${_currentMeal.quantity.toStringAsFixed(1)} ${_currentMeal.unitSymbol}',
            ),
            DetailListItem(
              icon: Icons.access_time,
              label: t.translate('logged'),
              value: timeago.format(_currentMeal.timestamp),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailListItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DetailListItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 28, color: const Color(0xFF4A90D9)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
