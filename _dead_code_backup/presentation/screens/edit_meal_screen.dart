import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_constants.dart';
import '../../core/utils/app_translations.dart';
import '../../data/models/food_item.dart';
import '../cubit/food_log_cubit.dart';

class EditMealScreen extends StatefulWidget {
  final FoodItem meal;

  const EditMealScreen({
    super.key,
    required this.meal,
  });

  @override
  State<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends State<EditMealScreen> {
  late FoodItem editableMeal;
  late FoodItem originalMeal;
  bool hasChanges = false;

  @override
  void initState() {
    super.initState();
    editableMeal = widget.meal;
    originalMeal = widget.meal;
  }

  void _checkChanges(FoodItem newMeal) {
    final changed = newMeal.name != originalMeal.name ||
        newMeal.calories != originalMeal.calories ||
        newMeal.protein != originalMeal.protein ||
        newMeal.carbs != originalMeal.carbs ||
        newMeal.fat != originalMeal.fat ||
        newMeal.quantity != originalMeal.quantity;
    if (changed != hasChanges) {
      setState(() {
        hasChanges = changed;
      });
    }
  }

  void _showConfirmDialog(BuildContext context) {
    final t = AppTranslations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text(t.translate('confirm_changes'),
                style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.translate('changes_summary'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white),
              ),
              SizedBox(height: 16),
              if (originalMeal.calories != editableMeal.calories)
                _buildChangeRow(
                  Icons.local_fire_department,
                  t.translate('calories'),
                  '${originalMeal.calories.toInt()} → ${editableMeal.calories.toInt()}',
                  originalMeal.calories,
                  editableMeal.calories,
                ),
              if (originalMeal.protein != editableMeal.protein)
                _buildChangeRow(
                  Icons.fitness_center,
                  t.translate('protein'),
                  '${originalMeal.protein.toInt()}g → ${editableMeal.protein.toInt()}g',
                  originalMeal.protein,
                  editableMeal.protein,
                ),
              if (originalMeal.carbs != editableMeal.carbs)
                _buildChangeRow(
                  Icons.grain,
                  t.translate('carbs'),
                  '${originalMeal.carbs.toInt()}g → ${editableMeal.carbs.toInt()}g',
                  originalMeal.carbs,
                  editableMeal.carbs,
                ),
              if (originalMeal.fat != editableMeal.fat)
                _buildChangeRow(
                  Icons.oil_barrel,
                  t.translate('fat'),
                  '${originalMeal.fat.toInt()}g → ${editableMeal.fat.toInt()}g',
                  originalMeal.fat,
                  editableMeal.fat,
                ),
              if (originalMeal.quantity != editableMeal.quantity)
                _buildChangeRow(
                  Icons.scale,
                  t.translate('quantity'),
                  '${originalMeal.quantity.toInt()} → ${editableMeal.quantity.toInt()}',
                  originalMeal.quantity,
                  editableMeal.quantity,
                ),
              if (originalMeal.name != editableMeal.name)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t.translate('meal_name')}:',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text('${originalMeal.name} → ${editableMeal.name}',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.translate('cancel'),
                style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _saveMeal(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(t.translate('confirm')),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeRow(IconData icon, String label, String change,
      double oldVal, double newVal) {
    final isIncrease = newVal > oldVal;
    final diffColor = isIncrease ? Colors.red : Colors.green;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          Icon(
            isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
            color: diffColor,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            change,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: diffColor,
            ),
          ),
        ],
      ),
    );
  }

  void _saveMeal(BuildContext context) {
    context.read<FoodLogCubit>().updateMeal(editableMeal);
    Navigator.pop(context, editableMeal);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    final unitSymbol = editableMeal.unit == FoodUnit.milliliters ? 'ml' : 'g';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(t.translate('edit_meal'),
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () => _showConfirmDialog(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: Colors.white, size: 20),
                SizedBox(width: 4),
                Text(t.translate('confirm'),
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: t.translate('meal_name'),
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              controller: TextEditingController(text: editableMeal.name),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                editableMeal = editableMeal.copyWith(name: value);
                _checkChanges(editableMeal);
              },
            ),
            TextField(
              decoration: InputDecoration(
                labelText:
                    '${t.translate('calories')} (${t.translate('kcal')})',
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(
                  text: editableMeal.calories.toStringAsFixed(1)),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                editableMeal = editableMeal.copyWith(
                    calories: double.tryParse(value) ?? 0.0);
                _checkChanges(editableMeal);
              },
            ),
            TextField(
              decoration: InputDecoration(
                labelText: '${t.translate('protein')} g',
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(
                  text: editableMeal.protein.toStringAsFixed(1)),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                editableMeal = editableMeal.copyWith(
                    protein: double.tryParse(value) ?? 0.0);
                _checkChanges(editableMeal);
              },
            ),
            TextField(
              decoration: InputDecoration(
                labelText: '${t.translate('carbs')} g',
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(
                  text: editableMeal.carbs.toStringAsFixed(1)),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                editableMeal =
                    editableMeal.copyWith(carbs: double.tryParse(value) ?? 0.0);
                _checkChanges(editableMeal);
              },
            ),
            TextField(
              decoration: InputDecoration(
                labelText: '${t.translate('fat')} g',
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(
                  text: editableMeal.fat.toStringAsFixed(1)),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                editableMeal =
                    editableMeal.copyWith(fat: double.tryParse(value) ?? 0.0);
                _checkChanges(editableMeal);
              },
            ),
            TextField(
              decoration: InputDecoration(
                labelText: '${t.translate('quantity')} $unitSymbol',
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(
                  text: editableMeal.quantity.toStringAsFixed(1)),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                editableMeal = editableMeal.copyWith(
                    quantity: double.tryParse(value) ?? 0.0);
                _checkChanges(editableMeal);
              },
            ),
            if (hasChanges) ...[
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.translate('changes_pending'),
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
