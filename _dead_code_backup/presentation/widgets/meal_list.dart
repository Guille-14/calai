import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/food_item.dart';
import '../screens/meal_detail_screen.dart';
import '../cubit/food_log_cubit.dart';
import 'meal_list_item.dart';
import 'package:timeago/timeago.dart' as timeago;

class MealList extends StatelessWidget {
  final List<FoodItem> meals;

  const MealList({
    required this.meals,
    super.key,
  });

  List<FoodItem> _getSortedMeals() {
    final sorted = List<FoodItem>.from(meals);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final sortedMeals = _getSortedMeals();

    if (sortedMeals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              'No meals logged today',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the scan button to add your first meal!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedMeals.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final meal = sortedMeals[index];
        return RepaintBoundary(
          child: GestureDetector(
            onLongPress: () => _showDeleteDialog(context, meal),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MealDetailScreen(meal: meal),
                ),
              );
            },
            child: MealListItem(
              meal: meal,
              timeAgo: timeago.format(meal.timestamp),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, FoodItem meal) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Delete Meal', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this meal?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<FoodLogCubit>().deleteMeal(meal);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
