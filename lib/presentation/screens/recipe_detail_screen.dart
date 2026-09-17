import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/recipe_model.dart';
import '../../core/theme/app_theme.dart';
import 'add_edit_recipe_screen.dart';

class RecipeDetailScreen extends StatelessWidget {
  final RecipeModel recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Receta', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddEditRecipeScreen(recipe: recipe)),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: recipe.localImagePath != null 
                  ? Image.file(
                      File(recipe.localImagePath!),
                      height: 250, width: double.infinity, fit: BoxFit.cover,
                    )
                  : Container(
                      height: 250,
                      width: double.infinity,
                      color: AppColors.divider,
                      child: const Icon(Icons.restaurant, size: 100, color: AppColors.textTertiary),
                    ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              recipe.name,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              recipe.description,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            _buildMacrosSection(context),
            const SizedBox(height: 32),
            _buildSectionTitle('Ingredientes'),
            ...recipe.ingredients.map((ing) => _buildItemRow(ing)),
            const SizedBox(height: 32),
            _buildSectionTitle('Instrucciones'),
            ...recipe.instructions.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: colors.primary,
                      child: Text('${entry.key + 1}', style: const TextStyle(color: AppColors.background, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16))),
                  ],
                ),
              );
            }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrosSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMacro('Kcal', recipe.calories.toString(), AppColors.accent),
          _buildMacro('Proteína', '${recipe.protein}g', AppColors.accent),
          _buildMacro('Carbos', '${recipe.carbs}g', AppColors.accent),
          _buildMacro('Grasas', '${recipe.fat}g', AppColors.accent),
        ],
      ),
    );
  }

  Widget _buildMacro(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildItemRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}
