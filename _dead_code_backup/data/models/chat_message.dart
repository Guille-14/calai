class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? imageUrl;
  final bool isTyping;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
    this.isTyping = false,
  });

  factory ChatMessage.user({
    required String content,
    String? imageUrl,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
    );
  }

  factory ChatMessage.ai({
    required String content,
    String? imageUrl,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
    );
  }

  factory ChatMessage.typing() {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isTyping: true,
    );
  }

  ChatMessage copyWith({
    String? content,
    String? imageUrl,
    bool? isTyping,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      isUser: isUser,
      timestamp: timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}
