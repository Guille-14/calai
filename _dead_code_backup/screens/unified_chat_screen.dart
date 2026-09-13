import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../models/food_entry.dart';
import '../models/health_context.dart';
import '../core/fitness_ai.dart';
import '../data/services/food_service.dart';
import '../data/services/health_settings_service.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';



/// Chat bubble widget for displaying messages
class ChatBubbleWidget extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const ChatBubbleWidget({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final Color bubbleColor = isMe
        ? Theme.of(context).primaryColor.withOpacity(0.9)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final Color textColor =
        isMe ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 20 : 4),
            topRight: Radius.circular(isMe ? 4 : 20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.type == ChatMessageType.nutritionCard &&
                message.jsonPayload != null)
              FoodHeavyCardWidget(
                foodEntry: FoodEntry.fromJson(message.jsonPayload!),
                onTap: () {
                  // Handle tap on food card if needed
                },
              )
            else
              Text(
                message.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget for displaying food nutrition information as a card
class FoodHeavyCardWidget extends StatelessWidget {
  final FoodEntry foodEntry;
  final VoidCallback? onTap;

  const FoodHeavyCardWidget({
    super.key,
    required this.foodEntry,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food name and confidence score
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      foodEntry.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(foodEntry.confidenceScore * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Nutrition facts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NutrientItem(
                    label: 'Calories',
                    value: '${foodEntry.calories.toStringAsFixed(0)} kcal',
                    icon: Icons.local_fire_department,
                  ),
                  _NutrientItem(
                    label: 'Protein',
                    value: '${foodEntry.protein.toStringAsFixed(1)}g',
                    icon: Icons.fitness_center,
                  ),
                  _NutrientItem(
                    label: 'Carbs',
                    value: '${foodEntry.carbs.toStringAsFixed(1)}g',
                    icon: Icons.bakery_dining,
                  ),
                  _NutrientItem(
                    label: 'Fat',
                    value: '${foodEntry.fat.toStringAsFixed(1)}g',
                    icon: Icons.egg,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutrientItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _NutrientItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Loading bubble widget for shimmer effect
class LoadingBubbleWidget extends StatelessWidget {
  final bool isMe;

  const LoadingBubbleWidget({
    super.key,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor = isMe
        ? Theme.of(context).primaryColor.withOpacity(0.3)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 20 : 4),
            topRight: Radius.circular(isMe ? 4 : 20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: baseColor.withOpacity(0.5),
          child: Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified chat screen
class UnifiedChatScreen extends StatefulWidget {
  const UnifiedChatScreen({super.key});

  @override
  State<UnifiedChatScreen> createState() => _UnifiedChatScreenState();
}

class _UnifiedChatScreenState extends State<UnifiedChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isImageMode = false;
  bool _isLoading = false;
  Uint8List? _selectedImage;

  FitnessAI? _fitnessAi;

  @override
  void initState() {
    super.initState();
    _initAi();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addSystemMessage(
          'Hello! I\'m your nutrition assistant. How can I help you today?');
    });
  }

  Future<void> _initAi() async {
    _fitnessAi = await FitnessAI.getInstance();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addSystemMessage(String text) {
    final chatState = Provider.of<ChatState>(context, listen: false);
    chatState.addMessage(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        sender: 'system',
        timestamp: DateTime.now(),
        type: ChatMessageType.text,
      ),
    );
  }

  void _addUserMessage(String text) {
    final chatState = Provider.of<ChatState>(context, listen: false);
    chatState.addMessage(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        sender: 'user',
        timestamp: DateTime.now(),
        type: ChatMessageType.text,
      ),
    );
  }

  void _addAssistantMessage(String text, {Map<String, dynamic>? jsonPayload}) {
    final chatState = Provider.of<ChatState>(context, listen: false);
    ChatMessageType type = ChatMessageType.text;

    // Check if the text contains JSON that looks like a food entry
    if (jsonPayload != null &&
        jsonPayload.containsKey('name') &&
        jsonPayload.containsKey('calories') &&
        jsonPayload.containsKey('protein') &&
        jsonPayload.containsKey('carbs') &&
        jsonPayload.containsKey('fat')) {
      type = ChatMessageType.nutritionCard;
    }

    chatState.addMessage(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        sender: 'assistant',
        timestamp: DateTime.now(),
        type: type,
        jsonPayload: jsonPayload,
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    if (text.isNotEmpty) {
      _addUserMessage(text);
    }

    _textController.clear();
    setState(() {
      _isImageMode = false;
      _selectedImage = null;
      _isLoading = true;
    });

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    try {
      if (_selectedImage != null) {
        // Use FoodService for image analysis
        final result =
            await FoodService.analyzeFoodImageFromBytes(_selectedImage!);
        if (result.isError) {
          _addSystemMessage(
              result.errorMessage ?? 'Sorry, I couldn\'t process the image.');
        } else {
          final jsonPayload = result.toFoodEntryPayload();
          _addAssistantMessage('¡He añadido esto a tu registro diario!',
              jsonPayload: jsonPayload);
          final health =
              Provider.of<HealthSettingsService>(context, listen: false);
          health.addFoodEntry(
            result.estimatedCalories,
            result.protein,
            result.carbs,
            result.fat,
          );
        }
      } else {
        // Use FitnessAI for text messages
        if (_fitnessAi == null) await _initAi();

        final coachResponse = await _fitnessAi!.getCoachResponse(text);
        _addAssistantMessage(coachResponse.message);

        if (coachResponse.suggestions.isNotEmpty) {
          _addSystemMessage(
              'Sugerencias: ${coachResponse.suggestions.join(', ')}');
        }
      }
    } catch (e) {
      _addSystemMessage('Sorry, I encountered an error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = bytes;
          _isImageMode = true;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _toggleImageMode() {
    setState(() {
      _isImageMode = !_isImageMode;
      if (!_isImageMode) {
        _selectedImage = null;
      }
    });

    if (_isImageMode) {
      _pickImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatState(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nutrition AI Chat'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Refresh health data
                final healthService =
                    Provider.of<HealthSettingsService>(context, listen: false);
                healthService.fetchTodayHealthContext();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Chat messages
            Expanded(
              child: Consumer<ChatState>(
                builder: (context, chatState, child) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length +
                        (_isLoading ? 1 : 0), // Extra item for loading state
                    itemBuilder: (context, index) {
                      // Show loading bubble at the end if loading
                      if (_isLoading && index == chatState.messages.length) {
                        return const LoadingBubbleWidget(isMe: false);
                      }

                      final message = chatState.messages[index];
                      final bool isMe = message.sender == 'user';

                      return message.sender == 'system'
                          ? Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              child: Text(
                                message.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            )
                          : ChatBubbleWidget(
                              message: message,
                              isMe: isMe,
                            );
                    },
                  );
                },
              ),
            ),

            // Input area
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  // Camera button (when input is empty) or Send button (when input has text)
                  GestureDetector(
                    onTap: _textController.text.isEmpty
                        ? _toggleImageMode
                        : _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _textController.text.isEmpty
                            ? Theme.of(context).primaryColor.withOpacity(0.2)
                            : Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _textController.text.isEmpty
                            ? (_isImageMode ? Icons.close : Icons.camera_alt)
                            : Icons.send,
                        color: _textController.text.isEmpty
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      minLines: 1,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: _isImageMode
                            ? 'Image selected. Add description...'
                            : 'Ask about food, nutrition, or health...',
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ),

                  // Image preview (if image selected)
                  if (_selectedImage != null && _isImageMode)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: MemoryImage(_selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat state management using ChangeNotifier
class ChatState extends ChangeNotifier {
  final List<ChatMessage> _messages = [];

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
