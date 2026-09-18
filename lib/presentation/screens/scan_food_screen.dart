import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_constants.dart';
import '../../core/utils/app_translations.dart';
import '../../data/models/food_item.dart';
import '../../data/services/ai_gateway.dart';
import '../cubit/food_log_cubit.dart';
import '../widgets/ai_analysis_progress.dart';
import 'ai_settings_screen.dart';
import 'openrouter_diagnostics_screen.dart';
import 'nutritional_chat_screen.dart';

class ScanFoodScreen extends StatefulWidget {
  final VoidCallback? onClose;

  const ScanFoodScreen({super.key, this.onClose});

  @override
  State<ScanFoodScreen> createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends State<ScanFoodScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<ScanFoodScreen> {
  @override
  bool get wantKeepAlive => true;
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _selectedImageBytes;
  File? _selectedImageFile;
  bool _isAnalyzing = false;
  AiAnalysisStage _analysisStage = AiAnalysisStage.preparing;
  String? _errorMessage;
  String? _configIssue;
  FoodAnalysisResult? _analysisResult;

  late AnimationController _pulseController;

  /// Temporizadores que hacen avanzar los micro-estados de progreso mientras
  /// la llamada a la IA sigue pendiente.
  final List<Timer> _stageTimers = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _checkAiConfiguration();
  }

  /// Comprueba si la IA puede analizar antes de que el usuario gaste una foto
  /// en descubrir que no. De fábrica el proveedor es Ollama en localhost, que
  /// en el móvil no existe.
  Future<void> _checkAiConfiguration() async {
    final issue = await AiGateway.configurationIssue();
    if (mounted) setState(() => _configIssue = issue);
  }

  @override
  void dispose() {
    _cancelStageTimers();
    _pulseController.dispose();
    super.dispose();
  }

  void _cancelStageTimers() {
    for (final timer in _stageTimers) {
      timer.cancel();
    }
    _stageTimers.clear();
  }

  /// Avanza los micro-estados por tiempo, no solo cuando resuelve la promesa.
  ///
  /// El análisis es una única llamada, así que antes el usuario se quedaba
  /// mirando "Analizando tu plato..." durante todos los segundos que tardara:
  /// se percibía como que la app se había colgado. Los temporizadores hacen
  /// visible que el trabajo avanza. Si la respuesta llega antes, se cancelan.
  void _startStageTimers() {
    _cancelStageTimers();
    void schedule(Duration delay, AiAnalysisStage stage) {
      _stageTimers.add(Timer(delay, () {
        if (!mounted || !_isAnalyzing) return;
        setState(() => _analysisStage = stage);
      }));
    }

    schedule(const Duration(milliseconds: 800), AiAnalysisStage.analyzing);
    schedule(const Duration(milliseconds: 1800), AiAnalysisStage.validating);
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
    // Impacto suave al disparar: sin feedback táctil la captura se siente
    // "muerta" y el usuario no sabe si el botón registró el toque.
    HapticFeedback.lightImpact();
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
    } catch (error, stack) {
      debugPrint('ScanFood: error seleccionando imagen: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo seleccionar la imagen. Inténtalo de nuevo.';
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImageBytes == null) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isAnalyzing = true;
      _analysisStage = AiAnalysisStage.preparing;
      _errorMessage = null;
      _analysisResult = null;
    });

    // Los micro-estados avanzan por tiempo mientras la IA responde.
    _startStageTimers();

    try {
      final result =
          await AiGateway.analyzeFoodImageFromBytes(_selectedImageBytes!);

      _cancelStageTimers();
      if (!mounted) return;
      setState(() {
        _analysisStage = AiAnalysisStage.validating;
        _analysisResult = result;
      });
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
      });

      // Confirmación háptica al completar el análisis: el usuario nota que
      // terminó sin tener que estar mirando la pantalla.
      if (!result.isError) HapticFeedback.heavyImpact();

      if (!result.isError) {
        await _saveFood(result);
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
        });
      }
    } catch (error, stack) {
      debugPrint('ScanFood: error analizando imagen: $error\n$stack');
      _cancelStageTimers();
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'No se pudo analizar la imagen. Inténtalo de nuevo.';
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
      aiModel: AiGateway.model,
    );

    if (!mounted) return;

    // Antes la comida se guardaba AQUÍ antes de mostrar el diálogo: si el
    // usuario pulsaba "Volver", quedaba registrada igualmente. Ahora solo
    // se guarda al confirmar dentro del diálogo.
    await _showFoodResultDialog(foodItem);
  }

  Future<void> _showFoodResultDialog(FoodItem foodItem) async {
    final nameController = TextEditingController(text: foodItem.name);

    // Ración estimada por la IA. El usuario puede corregirla y todos los
    // macros se reescalan proporcionalmente sobre esta referencia.
    final baseGrams =
        foodItem.quantity > 0 ? foodItem.quantity.toDouble() : 100.0;
    var grams = baseGrams;

    try {
      await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final portionFactor = baseGrams > 0 ? grams / baseGrams : 1.0;
          return Container(
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
                    color: AppColors.textTertiary,
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
                          color: AppColors.textPrimary,
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
                            controller: nameController,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'Nombre del alimento',
                              hintStyle: TextStyle(
                                  color: AppColors.textPrimary.withValues(alpha: 0.3)),
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.edit,
                                  color: AppColors.textSecondary, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.divider),
                    const SizedBox(height: 12),
                    _buildMacroRow(
                        'Calorías',
                        '${(foodItem.calories * portionFactor).round()} kcal',
                        AppColors.accent),
                    _buildMacroRow(
                        'Proteína',
                        '${(foodItem.protein * portionFactor).round()}g',
                        AppColors.accent),
                    _buildMacroRow(
                        'Carbohidratos',
                        '${(foodItem.carbs * portionFactor).round()}g',
                        AppColors.accent),
                    _buildMacroRow(
                        'Grasa',
                        '${(foodItem.fat * portionFactor).round()}g',
                        AppColors.accent),
                    const SizedBox(height: 12),
                    // Ajuste rápido de ración: la IA casi nunca acierta el peso
                    // exacto. Sin esto, corregir obligaba a abrir el teclado y
                    // reescribir cada macro a mano, y el usuario abandonaba.
                    _buildPortionNudge(
                      grams: grams,
                      onChanged: (next) {
                        HapticFeedback.selectionClick();
                        setSheetState(() => grams = next);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: AppColors.accent, size: 16),
                        const SizedBox(width: 6),
                        Text('IA: ${AiGateway.model}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
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
                        // Guardar = confirmar: única escritura, con el nombre
                        // final y la ración ya ajustada por el usuario.
                        final editedName = nameController.text.trim();
                        final finalName =
                            editedName.isNotEmpty ? editedName : foodItem.name;
                        context
                            .read<FoodLogCubit>()
                            .addMeal(_scaled(foodItem, finalName, portionFactor, grams));
                        HapticFeedback.mediumImpact();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textPrimary,
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
                    final editedName = nameController.text.trim();
                    context.read<FoodLogCubit>().addMeal(_scaled(
                        foodItem,
                        editedName.isNotEmpty ? editedName : foodItem.name,
                        portionFactor,
                        grams));
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
                      style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.4))),
                ),
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
            ],
          ),
        );
        },
      ),
    );
    } finally {
      nameController.dispose();
    }
  }

  /// Aplica la ración corregida por el usuario a todos los macros.
  FoodItem _scaled(
      FoodItem item, String name, double factor, double grams) {
    return item.copyWith(
      name: name,
      calories: item.calories * factor,
      protein: item.protein * factor,
      carbs: item.carbs * factor,
      fat: item.fat * factor,
      sugar: item.sugar * factor,
      quantity: grams,
    );
  }

  /// Ajuste rápido de ración en pasos, sin teclado numérico.
  Widget _buildPortionNudge({
    required double grams,
    required ValueChanged<double> onChanged,
  }) {
    Widget step(String label, double delta) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: OutlinedButton(
              onPressed: () {
                final next = (grams + delta).clamp(5.0, 2000.0);
                if (next != grams) onChanged(next.toDouble());
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.15)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: Size.zero,
              ),
              child: Text(label, style: const TextStyle(fontSize: 12)),
            ),
          ),
        );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Ración',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Text('${grams.round()} g',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            step('-50', -50),
            step('-10', -10),
            step('+10', 10),
            step('+50', 50),
          ],
        ),
      ],
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
                  Text(label, style: const TextStyle(color: AppColors.textSecondary))),
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
      _analysisStage = AiAnalysisStage.preparing;
      _isAnalyzing = false;
    });
    _showImageSourceDialog();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () {
            widget.onClose?.call();
            Navigator.pop(context);
          },
        ),
        title: Text(AppTranslations.of(context).translate('scan_food'),
            style: const TextStyle(color: AppColors.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: AppColors.textPrimary),
            onPressed: () => OpenRouterDiagnosticsScreen.show(context),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_selectedImageBytes == null) {
      return Column(
        children: [
          if (_configIssue != null) _buildConfigBanner(),
          Expanded(child: _buildEmptyState()),
        ],
      );
    }

    return Column(
      children: [
        if (_configIssue != null) _buildConfigBanner(),
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

  /// Aviso previo: la IA no está lista, con acceso directo a arreglarlo.
  Widget _buildConfigBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'La IA no está configurada',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _configIssue!,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
              await _checkAiConfiguration();
            },
            child: const Text('Configurar'),
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
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                foregroundColor: AppColors.background,
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
              AppColors.background.withValues(alpha: 0.8),
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
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.edit,
                          color: AppColors.textSecondary,
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
                  // El modelo solo devuelve low/medium/high. Mostrar "90%"
                  // inventa una precisión que la IA nunca calculó, así que se
                  // enseña la etiqueta cualitativa tal cual.
                  child: Text(
                    data.confidence == 'high'
                        ? 'Confianza alta'
                        : data.confidence == 'medium'
                            ? 'Confianza media'
                            : 'Confianza baja',
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
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'AI: ${AiGateway.model.split('/').last}',
                style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.7),
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
      color: AppColors.background.withValues(alpha: 0.7),
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
              // Un error sin salida deja al usuario atascado: casi todos los
              // fallos de análisis se arreglan en Ajustes IA (proveedor sin
              // configurar, modelo inexistente, servidor caído).
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _errorMessage = null),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reintentar'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AiSettingsScreen()),
                      );
                      if (mounted) setState(() => _errorMessage = null);
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Ajustes IA'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    final provider = switch (AiGateway.activeProvider) {
      'google' => 'Gemini',
      'openrouter' => 'OpenRouter',
      _ => 'Ollama',
    };
    return Container(
      color: AppColors.background.withValues(alpha: 0.5),
      child: Center(
        child: AiAnalysisProgress(
          stage: _analysisStage,
          provider: provider,
          model: AiGateway.model.split('/').last,
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
            color: AppColors.background.withValues(alpha: 0.1),
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
                        color: AppColors.textPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_isAnalyzing
                  ? t.translate('analyzing')
                  : t.translate('analyze_food')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textPrimary,
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
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
