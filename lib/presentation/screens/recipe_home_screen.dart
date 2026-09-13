import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/recipe_model.dart';
import '../../data/services/recipe_service.dart';
import '../widgets/tiktok_recipe_extractor.dart';
import 'add_edit_recipe_screen.dart';
import 'recipe_detail_screen.dart';

class RecipeHomeScreen extends StatefulWidget {
  const RecipeHomeScreen({super.key});

  @override
  State<RecipeHomeScreen> createState() => _RecipeHomeScreenState();
}

class _RecipeHomeScreenState extends State<RecipeHomeScreen> {
  final RecipeService _recipeService = RecipeService();
  List<RecipeModel> _recipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    final recipes = await _recipeService.getAllRecipes();
    setState(() {
      _recipes = recipes;
      _isLoading = false;
    });
  }

  void _showTikTokExtractor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Extraer Receta de TikTok', 
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Pega la descripción del video y la IA creará la receta.', 
                style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 24),
              TikTokRecipeExtractor(onRecipeAdded: () {
                Navigator.pop(ctx);
                _loadRecipes();
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Recetas', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
          actions: [
IconButton(
              icon: Icon(Icons.auto_awesome, color: AppColors.primaryAccent),
              onPressed: _showTikTokExtractor,
              tooltip: 'Extraer de TikTok con IA',
            ),
          ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: AppColors.primaryAccent))
        : _recipes.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _recipes.length,
              itemBuilder: (context, index) {
                final recipe = _recipes[index];
                return _buildRecipeCard(recipe);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditRecipeScreen()),
          );
          _loadRecipes();
        },
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text(
            'No hay recetas guardadas',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Empieza a añadir tus platos favoritos',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(RecipeModel recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: recipe.localImagePath != null 
            ? Image.file(
                File(recipe.localImagePath!), 
                width: 60, height: 60, fit: BoxFit.cover, 
                errorBuilder: (_, __, ___) => _buildDefaultImage()
              )
            : _buildDefaultImage(),
        ),
        title: Text(
          recipe.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '${recipe.calories} kcal | P: ${recipe.protein}g C: ${recipe.carbs}g G: ${recipe.fat}g',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
          );
          _loadRecipes(); // Recargar por si se editó o borró
        },
      ),
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.restaurant, color: Colors.white38),
    );
  }
}
