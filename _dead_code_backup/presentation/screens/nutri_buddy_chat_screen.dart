import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_constants.dart';
import '../../core/utils/app_translations.dart';
import '../../data/models/chat_message.dart';
import '../../data/services/food_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/ergonomic_image_picker_sheet.dart';

class NutriBuddyChatScreen extends StatefulWidget {
  const NutriBuddyChatScreen({super.key});

  @override
  State<NutriBuddyChatScreen> createState() => _NutriBuddyChatScreenState();
}

class _NutriBuddyChatScreenState extends State<NutriBuddyChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FoodService _foodService = FoodService();
  final List<ChatMessage> _messages = [];
  final Set<String> _animatedMessageIds = {};
  bool _isTyping = false;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _addInitialMessages();
    });
  }

  void _addInitialMessages() {
    final t = AppTranslations.of(context);
    final greeting = t.locale.languageCode == 'es'
        ? '¡Hola! Soy NutriBuddy, tu asistente nutricional personal. ¿En qué puedo ayudarte hoy? Puedo analizar fotos de comida, responder preguntas sobre nutrición o darte consejos saludables.'
        : 'Hello! I\'m NutriBuddy, your personal nutrition assistant. How can I help you today? I can analyze food photos, answer nutrition questions, or give you healthy tips.';
    _messages.add(ChatMessage.ai(content: greeting));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessageList()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final t = AppTranslations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentCalories.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.smart_toy,
              color: AppColors.accentCalories,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.translate('nutri_buddy'),
                  style: AppTextStyles.heading3.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isConnected
                          ? '${FoodService.model.split('/').last} AI'
                          : 'Offline',
                      style: AppTextStyles.caption.copyWith(
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        final showAnimation = !_animatedMessageIds.contains(message.id);
        final key = ValueKey(message.id);

        if (showAnimation && !message.isTyping) {
          _animatedMessageIds.add(message.id);
          return TweenAnimationBuilder<double>(
            key: key,
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: ChatBubble(message: message),
          );
        }

        return ChatBubble(key: key, message: message);
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildMicButton(),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField()),
              const SizedBox(width: 12),
              _buildSendButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    final t = AppTranslations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.secondary),
      ),
      child: TextField(
        controller: _messageController,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: t.translate('ask_nutrition'),
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textTertiary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: AppTextStyles.bodyLarge,
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accentCarbs.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.mic,
          color: AppColors.accentCarbs,
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final hasText = _messageController.text.trim().isNotEmpty;

    return GestureDetector(
      onTap: hasText ? _sendMessage : _showCameraOption,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasText
                ? [AppColors.accentCalories, AppColors.accentCalories]
                : [AppColors.royalBlue, AppColors.royalBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (hasText ? AppColors.accentCalories : AppColors.royalBlue)
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          hasText ? Icons.send : Icons.camera_alt,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _messages.add(ChatMessage.user(content: text));
      _messages.add(ChatMessage.typing());
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    _getAIResponse(text);
  }

  void _showCameraOption() {
    ErgonomicImagePickerSheet.show(
      context,
      onImageSelected: (bytes) => _analyzeImage(bytes),
    );
  }

  Future<void> _analyzeImage(Uint8List bytes) async {
    HapticFeedback.mediumImpact();

    setState(() {
      _messages.add(ChatMessage.user(
        content: 'Can you analyze this food?',
        imageUrl: 'analysis_image',
      ));
      _messages.add(ChatMessage.typing());
      _isTyping = true;
    });

    _scrollToBottom();

    final result = await _foodService.analyzeFoodImageFromBytes(bytes);

    _messages.removeWhere((m) => m.isTyping);

    if (result.isSuccess && result.data != null) {
      final data = result.data!;
      final nutritionInfo = '''
Name: ${data.name}
Calories: ${data.calories.toInt()} kcal
Protein: ${data.protein.toInt()}g
Carbs: ${data.carbs.toInt()}g
Fat: ${data.fat.toInt()}g
Confidence: ${(data.confidenceScore * 100).toInt()}%
''';
      _messages.add(ChatMessage.ai(
        content:
            'Based on my analysis of the image:\n\n$nutritionInfo\nWould you like me to add this to your daily log?',
      ));
    } else {
      _messages.add(ChatMessage.ai(
        content: result.errorMessage ??
            'I had trouble analyzing the image. Could you try again or describe what you\'re eating?',
      ));
    }

    setState(() {
      _isTyping = false;
      _isConnected = result.isSuccess;
    });
    _scrollToBottom();
  }

  Future<void> _getAIResponse(String question) async {
    final result = await _foodService.estimateCaloriesFromText(question);

    _messages.removeWhere((m) => m.isTyping);

    String response;
    if (result.isSuccess && result.data != null) {
      final data = result.data!;
      response = '''
Name: ${data.name}
Calories: ${data.calories.toInt()} kcal
Protein: ${data.protein.toInt()}g
Carbs: ${data.carbs.toInt()}g
Fat: ${data.fat.toInt()}g
''';
    } else {
      response = result.errorMessage ??
          'I\'m having trouble connecting to the AI. Please check your API key configuration.';
      setState(() => _isConnected = false);
    }

    _messages.add(ChatMessage.ai(content: response));

    setState(() => _isTyping = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
