import 'dart:typed_data';
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
import '../widgets/popups.dart';
import 'ai_settings_screen.dart';

class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FoodScannerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen>
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showImageSourceDialog();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
          color: AppColors.surface,
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
                    icon: Icons.camera_alt_rounded,
                    label: t.translate('camera'),
                    color: AppColors.accentCalories,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ImageSourceButton(
                    icon: Icons.photo_library_rounded,
                    label: t.translate('gallery'),
                    color: AppColors.royalBlue,
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
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            '${AppTranslations.of(context).translate('error_selecting')}: $e';
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

      if (!result.isError && result.foods.isNotEmpty) {
        await _saveFoodFromResult(result);
      } else if (result.isError) {
        setState(() {
          _errorMessage = result.errorMessage;
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage =
            '${AppTranslations.of(context).translate("error_analyzing")}: $e';
      });
    }
  }

  Future<void> _saveFoodFromResult(FoodAnalysisResult result) async {
    final foodId = DateTime.now().millisecondsSinceEpoch.toString();
    final foodName = result.foods.isNotEmpty ? result.foods.join(', ') : 'Comida';
    final unit = _inferUnit(foodName);

    final foodItem = FoodItem(
      id: foodId,
      name: foodName,
      calories: result.estimatedCalories.toDouble(),
      protein: result.protein,
      carbs: result.carbs,
      fat: result.fat,
      sugar: 0,
      quantity: 100,
      timestamp: DateTime.now(),
      ingredients: [],
      imageUrl: _selectedImageFile?.path,
      unit: unit,
      confidenceScore: result.confidence == 'high' ? 0.9 : (result.confidence == 'medium' ? 0.7 : 0.4),
    );

    if (!mounted) return;

    context.read<FoodLogCubit>().addMeal(foodItem);

    FoodAddedPopup.show(
      context,
      foodName: foodName,
      calories: result.estimatedCalories,
    );

    Navigator.pop(context);
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
    final t = AppTranslations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(t.translate('scan_food'),
            style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final t = AppTranslations.of(context);
    if (_selectedImageBytes == null) {
      return _buildEmptyState(t);
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

  Widget _buildEmptyState(AppTranslations t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.accentCalories.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: 64,
                color: AppColors.accentCalories,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t.translate('capture_food'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            t.translate('take_or_select'),
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showImageSourceDialog,
            icon: const Icon(Icons.add_a_photo),
            label: Text(t.translate('select_image')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCalories,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
            icon: const Icon(Icons.bug_report, size: 18),
            label: Text(t.translate('test_ai_connection')),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
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
            if (_analysisResult != null && !_analysisResult!.isError &&
                _analysisResult!.foods.isNotEmpty)
              _buildAnalysisOverlayFromResult(_analysisResult!),
            if (_errorMessage != null) _buildErrorOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisOverlayFromResult(FoodAnalysisResult result) {
    final t = AppTranslations.of(context);
    final foodName = result.foods.isNotEmpty ? result.foods.join(', ') : 'Comida';
    final confPercent = result.confidence == 'high' ? 90 : (result.confidence == 'medium' ? 70 : 40);
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
              children: [
                Expanded(
                  child: Text(
                    foodName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$confPercent%',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NutritionChip(
                  icon: Icons.local_fire_department,
                  label: t.translate('cal'),
                  value: '${result.estimatedCalories}',
                  color: AppColors.accentCalories,
                ),
                _NutritionChip(
                  icon: Icons.fitness_center,
                  label: t.translate('protein_short'),
                  value: '${result.protein.toInt()}g',
                  color: AppColors.accentProtein,
                ),
                _NutritionChip(
                  icon: Icons.bakery_dining,
                  label: t.translate('carbs_short'),
                  value: '${result.carbs.toInt()}g',
                  color: AppColors.accentCarbs,
                ),
                _NutritionChip(
                  icon: Icons.egg_alt,
                  label: t.translate('fat_short'),
                  value: '${result.fat.toInt()}g',
                  color: AppColors.accentFat,
                ),
              ],
            ),
          ],
        ),
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
                color: Colors.red.shade300,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ??
                    AppTranslations.of(context).translate('error_analyzing'),
                style: TextStyle(
                  color: Colors.red.shade200,
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
              t.translate('using_ai'),
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
        color: AppColors.surface,
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
                side: BorderSide(color: AppColors.accentCalories),
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
                backgroundColor: AppColors.accentCalories,
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
