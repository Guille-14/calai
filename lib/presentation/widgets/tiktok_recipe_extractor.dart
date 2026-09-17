import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/recipe_model.dart';
import '../../data/services/food_service.dart';
import '../../data/services/recipe_service.dart';
import 'package:uuid/uuid.dart';

class TikTokRecipeExtractor extends StatefulWidget {
  final VoidCallback onRecipeAdded;

  const TikTokRecipeExtractor({super.key, required this.onRecipeAdded});

  @override
  State<TikTokRecipeExtractor> createState() => _TikTokRecipeExtractorState();
}

class _TikTokRecipeExtractorState extends State<TikTokRecipeExtractor> {
  final _textController = TextEditingController();
  bool _isLoading = false;

  Future<void> _extractRecipe() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, pega la descripción o texto de la receta.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Antes usaba AiOrchestrator sin ningún adapter registrado: fallaba
      // siempre con "Ningún modelo configurado". Ahora usa FoodService,
      // que sí tiene proveedor activo (OpenRouter/Gemini/Ollama).
      final responseText = await FoodService.chatCompletion(
        'Convierte el siguiente texto de una receta de red social en JSON. '
        'Si faltan cantidades exactas, estima valores de porción estándar y '
        'calcula los macros a partir de los ingredientes. El nombre debe ser '
        'conciso y atractivo. Responde SOLO con JSON válido, sin texto extra:\n'
        '$text\n\n'
        'Formato exacto: {"name":"string","description":"string",'
        '"ingredients":["string"],"instructions":["string"],'
        '"calories":number,"protein":number,"carbs":number,"fat":number}',
        context: const [
          'Eres un experto nutricionista y chef. Conviertes texto desestructurado '
              'de redes sociales (TikTok, Instagram) en recetas precisas.',
        ],
      );

      if (responseText.startsWith('Error')) {
        throw Exception(responseText);
      }

      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(responseText);
      if (jsonMatch == null) {
        throw Exception('La IA no devolvió un formato válido');
      }
      final Map<String, dynamic> data;
      try {
        data = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('La IA no devolvió un JSON interpretable');
      }

      final recipe = RecipeModel(
        id: const Uuid().v4(),
        name: data['name']?.toString() ?? 'Receta Extraída',
        description: data['description']?.toString() ?? '',
        ingredients:
            List<String>.from(data['ingredients'] ?? []),
        instructions:
            List<String>.from(data['instructions'] ?? []),
        calories: ((data['calories'] as num?) ?? 0).toInt(),
        protein: ((data['protein'] as num?) ?? 0).toDouble(),
        carbs: ((data['carbs'] as num?) ?? 0).toDouble(),
        fat: ((data['fat'] as num?) ?? 0).toDouble(),
        createdAt: DateTime.now(),
      );

      await RecipeService().saveRecipe(recipe);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Receta extraída y guardada con éxito!')),
        );
        widget.onRecipeAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al extraer receta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _textController,
          maxLines: 5,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Pega aquí la descripción del video de TikTok...',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.textPrimary.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _extractRecipe,
            icon: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
              : const Icon(Icons.auto_awesome),
            label: Text(_isLoading ? 'Procesando...' : 'Extraer con IA', 
              style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),

          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
