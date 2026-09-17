import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_constants.dart';
import '../../core/utils/app_translations.dart';
import '../../data/models/food_item.dart';
import '../../data/services/food_service.dart';
import '../cubit/food_log_cubit.dart';
import 'openrouter_diagnostics_screen.dart';
import 'nutritional_chat_screen.dart';

class ScanFoodScreen extends StatefulWidget {
  final VoidCallback? onClose;

  const ScanFoodScreen({super.key, this.onClose});

  @override
  State<ScanFoodScreen> createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends State<ScanFoodScreen>
    with TickerProviderStateMixin {
  final FoodService _foodService = FoodService();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _selectedImageBytes;
  File? _selectedImageFile;
  bool _isAnalyzing = false;
  String? _errorMessage;
  FoodAnalysisResult? _analysisResult;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _maybePausePulse() {
    if (_selectedImageBytes != null && _pulseController.isAnimating) {
      _pulseController.stop();
    } else if (_selectedImageBytes == null && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _showImageSourceDialog() {
    final t = AppTranslations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t.translate('scan_food'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              t.translate('choose_capture'),
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _ImageSourceButton(
                    icon: Icons.camera_alt_outlined,
                    label: t.translate('camera'),
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ImageSourceButton(
                    icon: Icons.photo_library_outlined,
                    label: t.translate('gallery'),
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFile = File(pickedFile.path);
          _errorMessage = null;
          _analysisResult = null;
        });
        _maybePausePulse();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting image: $e';
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImageBytes == null) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _analysisResult = null;
    });

    try {
      final result =
          await FoodService.analyzeFoodImageFromBytes(_selectedImageBytes!);

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });

      if (!result.isError) {
        await _saveFood(result);
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Error analyzing image: $e';
      });
    }
  }

  Future<void> _saveFood(FoodAnalysisResult foodData) async {
    final foodId = DateTime.now().millisecondsSinceEpoch.toString();

    final initialName =
        foodData.foods.isNotEmpty ? foodData.foods.first : 'Comida';
    final unit = _inferUnit(initialName);
    final ingredients = <Ingredient>[];

    final foodItem = FoodItem(
      id: foodId,
      name: initialName,
      calories: foodData.estimatedCalories.toDouble(),
      protein: foodData.protein,
      carbs: foodData.carbs,
      fat: foodData.fat,
      sugar: foodData.sugar,
      quantity: 100,
      timestamp: DateTime.now(),
      ingredients: ingredients,
      imageUrl: _selectedImageFile?.path,
      unit: unit,
      confidenceScore: foodData.confidence == 'high'
          ? 0.9
          : foodData.confidence == 'medium'
              ? 0.7
              : 0.5,
      aiModel: FoodService.model,
    );

    if (!mounted) return;

    // Antes la comida se guardaba AQUÍ antes de mostrar el diálogo: si el
    // usuario pulsaba "Volver", quedaba registrada igualmente. Ahora solo
    // se guarda al confirmar dentro del diálogo.
    await _showFoodResultDialog(foodItem, foodData);
  }

  Future<void> _showFoodResultDialog(
      FoodItem foodItem, FoodAnalysisResult foodData) async {
    String editedName = foodItem.name;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.elevatedCardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.accent, size: 28),
                  const SizedBox(width: 12),
                  const Text('Alimento Escaneado',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.elevatedCardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: editedName),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'Nombre del alimento',
                              hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3)),
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.edit,
                                  color: Colors.white54, size: 20),
                            ),
                            onChanged: (value) => editedName = value,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    _buildMacroRow(
                        'Calorías',
                        '${foodItem.calories.toInt()} kcal',
                        AppColors.accent),
                    _buildMacroRow('Proteína', '${foodItem.protein.toInt()}g',
                        AppColors.accent),
                    _buildMacroRow('Carbohidratos',
                        '${foodItem.carbs.toInt()}g', AppColors.accent),
                    _buildMacroRow(
                        'Grasa', '${foodItem.fat.toInt()}g', AppColors.accent),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: AppColors.accent, size: 16),
                        const SizedBox(width: 6),
                        Text('IA: ${FoodService.model}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Guardar = confirmar: única escritura, con el nombre final.
                        final finalName =
                            editedName.trim().isNotEmpty ? editedName : foodItem.name;
                        context.read<FoodLogCubit>().addMeal(
                              finalName == foodItem.name
                                  ? foodItem
                                  : foodItem.copyWith(name: finalName),
                            );
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Confirmar también al ir al chat (el usuario quiere hablar
                    // de este alimento ya registrado).
                    context.read<FoodLogCubit>().addMeal(foodItem);
                    Navigator.pop(ctx);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NutritionalChatScreen()));
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chatear con IA sobre este alimento'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Volver',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                ),
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(label, style: const TextStyle(color: Colors.white54))),
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  FoodUnit _inferUnit(String foodName) {
    final lower = foodName.toLowerCase();
    final liquids = ['agua', 'juice', 'soda', 'coffee', 'tea', 'soup', 'milk'];
    for (final l in liquids) {
      if (lower.contains(l)) return FoodUnit.milliliters;
    }
    return FoodUnit.grams;
  }

  void _reset() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageFile = null;
      _errorMessage = null;
      _analysisResult = null;
      _isAnalyzing = false;
    });
    _showImageSourceDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            widget.onClose?.call();
            Navigator.pop(context);
          },
        ),
        title: Text(AppTranslations.of(context).translate('scan_food'),
            style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: () => OpenRouterDiagnosticsScreen.show(context),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_selectedImageBytes == null) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              _buildImagePreview(),
              if (_isAnalyzing) _buildLoadingOverlay(),
            ],
          ),
        ),
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2), width: 2),
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              size: 80,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 48),
          const Text(
            'Toma una foto o selecciona de la galería',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 220,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _showImageSourceDialog,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Seleccionar Imagen',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              _selectedImageBytes!,
              fit: BoxFit.cover,
            ),
            if (_analysisResult?.isError == false)
              _buildAnalysisOverlay(_analysisResult!),
            if (_errorMessage != null) _buildErrorOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisOverlay(FoodAnalysisResult data) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showEditNameDialog(data),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.foods.isNotEmpty ? data.foods.first : 'Comida',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.edit,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data.confidence == 'high'
                        ? '90%'
                        : data.confidence == 'medium'
                            ? '70%'
                            : '50%',
                    style: const TextStyle(
                      color: AppColors.accentStrong,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'AI: ${FoodService.model.split('/').last}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NutritionChip(
                  icon: Icons.local_fire_department,
                  label: 'Cal',
                  value: '${data.estimatedCalories}',
                  color: AppColors.accent,
                ),
                _NutritionChip(
                  icon: Icons.fitness_center,
                  label: 'Protein',
                  value: '${data.protein.toInt()}g',
                  color: AppColors.accent,
                ),
                _NutritionChip(
                  icon: Icons.bakery_dining,
                  label: 'Carbs',
                  value: '${data.carbs.toInt()}g',
                  color: AppColors.accent,
                ),
                _NutritionChip(
                  icon: Icons.egg_alt,
                  label: 'Fat',
                  value: '${data.fat.toInt()}g',
                  color: AppColors.accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(FoodAnalysisResult data) {
    final currentName = data.foods.isNotEmpty ? data.foods.first : 'Comida';
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Food Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Food Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                setState(() {
                  _analysisResult = FoodAnalysisResult(
                    foods: [newName],
                    estimatedCalories: data.estimatedCalories,
                    protein: data.protein,
                    carbs: data.carbs,
                    fat: data.fat,
                    sugar: data.sugar,
                    confidence: data.confidence,
                  );
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Error analyzing image',
                style: TextStyle(
                  color: AppColors.error.withValues(alpha: 0.85),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    final t = AppTranslations.of(context);
    final modelName = FoodService.model.split('/').last;
    // Nombre visible del proveedor real (antes decía siempre "Ollama").
    final provider = switch (FoodService.activeProvider) {
      'google' => 'Gemini',
      'openrouter' => 'OpenRouter',
      _ => 'Ollama',
    };
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              t.translate('analyzing_food'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${t.translate('using_ai')} ($provider: $modelName)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final t = AppTranslations.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: Text(t.translate('new_image')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeImage,
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_isAnalyzing
                  ? t.translate('analyzing')
                  : t.translate('analyze_food')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _NutritionChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
