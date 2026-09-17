import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_constants.dart';
import '../../core/utils/app_translations.dart';
import '../../core/symmetry/symmetry_progression_service.dart';
import '../../data/services/food_service.dart';

class _ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _ChatMessage.fromJson(Map<String, dynamic> json) => _ChatMessage(
        id: json['id'],
        content: json['content'],
        isUser: json['isUser'],
        timestamp: DateTime.parse(json['timestamp']),
      );

  String toHistoryEntry() {
    return '${isUser ? 'Usuario' : 'Asistente'}: $content';
  }
}

class NutritionalChatScreen extends StatefulWidget {
  const NutritionalChatScreen({super.key});

  @override
  State<NutritionalChatScreen> createState() => _NutritionalChatScreenState();
}

class _NutritionalChatScreenState extends State<NutritionalChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final SymmetryProgressionService _symmetry = SymmetryProgressionService();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  String? _error;
  bool _isLoading = true;

  static const String _messagesKey = 'chat_messages';

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    try {
      await FoodService.initFromPrefs();
    } catch (e) {
      debugPrint('FoodService init error: $e');
    }
    try {
      await _symmetry.initialize();
    } catch (e) {
      debugPrint('SymmetryProgressionService init error: $e');
    }
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_messagesKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        if (decoded.isNotEmpty) {
          setState(() {
            _messages
                .addAll(decoded.map((e) => _ChatMessage.fromJson(e)).toList());
            _isLoading = false;
          });
          _scrollToBottom();
          return;
        }
      } catch (_) {}
    }
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addWelcomeMessage();
      });
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _messages.map((m) => m.toJson()).toList();
    await prefs.setString(_messagesKey, jsonEncode(jsonList));
  }

  void _addWelcomeMessage() {
    final t = AppTranslations.of(context);
    final locale = t.locale.languageCode;
    final welcome = locale == 'es'
        ? '¡Hola! Soy tu asistente de nutrición y fitness. Pregúntame lo que quieras sobre calorías, macros, dietas, ejercicios o cualquier tema de salud y bienestar. ¿En qué puedo ayudarte?'
        : 'Hello! I\'m your nutrition and fitness assistant. Ask me anything about calories, macros, diets, exercises, or any health and wellness topic. How can I help you?';
    _messages.add(_ChatMessage(
      id: 'welcome',
      content: welcome,
      isUser: false,
      timestamp: DateTime.now(),
    ));
    _saveMessages();
    setState(() => _isLoading = false);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isTyping) return;

    _messageController.clear();
    setState(() {
      _messages.add(_ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      // Historial con los mensajes más recientes (usuario y asistente):
      final recentMessages = _messages.length > 10
          ? _messages.sublist(_messages.length - 10)
          : _messages;
      final history =
          recentMessages.map((m) => m.toHistoryEntry()).toList();

      // Inyectar contexto físico (servicio ya inicializado en _initializeAndLoad)
      final stats = _symmetry.getProgress();
      final contextStr = 'Contexto Físico Hoy: Has ganado ${stats.dailyXP.toStringAsFixed(0)} XP. Nivel: ${stats.currentRank.displayName}. Rango completado: ${(stats.rankProgress*100).toStringAsFixed(1)}%.';
      history.insert(0, contextStr);

      final response = await FoodService.chatCompletion(
        text,
        context: history,
      );

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: response,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isTyping = false;
        });
        _saveMessages();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isTyping = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t.translate('nutrition_chat'),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _clearChat,
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
                ),
                if (_error != null) _buildErrorBar(),
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildErrorBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _error = null),
            child: const Text('Dismiss', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.smart_toy,
                size: 18,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? AppColors.accent
                    : AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 20),
                ),
                boxShadow: message.isUser ? null : AppShadows.soft,
              ),
              child: SelectableText(
                message.content,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: message.isUser ? Colors.white : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person,
                size: 18,
                color: AppColors.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.smart_toy,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(index),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color:
                AppColors.textTertiary.withValues(alpha: 0.3 + (value * 0.7)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText:
                      AppTranslations.of(context).translate('ask_nutrition'),
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent,
                    AppColors.accent.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
            'Are you sure you want to clear the entire chat history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_messagesKey);
              if (mounted) {
                setState(() {
                  _messages.clear();
                  _isLoading = true;
                });
                _addWelcomeMessage();
              }
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
