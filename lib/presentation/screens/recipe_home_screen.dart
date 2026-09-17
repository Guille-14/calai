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
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    if (mounted) setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final recipes = await _recipeService.getAllRecipes();
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'No se pudieron cargar las recetas';
      });
      debugPrint('RecipeHome: error cargando recetas: $error');
    }
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
                decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Extraer Receta de TikTok', 
                style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Pega la descripción del video y la IA creará la receta.', 
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
          actions: [
IconButton(
              icon: Icon(Icons.auto_awesome, color: AppColors.accent),
              onPressed: _showTikTokExtractor,
              tooltip: 'Extraer de TikTok con IA',
            ),
          ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
        : _loadError != null
          ? _buildLoadError()
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
        child: const Icon(Icons.add, color: AppColors.background),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          Text(_loadError!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadRecipes,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: AppColors.textPrimary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text(
            'No hay recetas guardadas',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Empieza a añadir tus platos favoritos',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
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
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.05)),
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
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '${recipe.calories} kcal | P: ${recipe.protein}g C: ${recipe.carbs}g G: ${recipe.fat}g',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
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
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.restaurant, color: AppColors.textTertiary),
    );
  }
}
