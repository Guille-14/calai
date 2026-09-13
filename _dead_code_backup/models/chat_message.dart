
enum ChatMessageType { text, nutritionCard, imageRequest }

class ChatMessage {
  final String id;
  final String text;
  final String sender; // 'user', 'assistant', 'system'
  final DateTime timestamp;
  final ChatMessageType type;
  final Map<String, dynamic>? jsonPayload;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    required this.type,
    this.jsonPayload,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      sender: json['sender'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: ChatMessageType.values.firstWhere(
        (e) => e.toString() == 'ChatMessageType.${json['type']}',
        orElse: () => ChatMessageType.text,
      ),
      jsonPayload: json['jsonPayload'] != null
          ? Map<String, dynamic>.from(json['jsonPayload'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
      'jsonPayload': jsonPayload,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? text,
    String? sender,
    DateTime? timestamp,
    ChatMessageType? type,
    Map<String, dynamic>? jsonPayload,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      jsonPayload: jsonPayload ?? this.jsonPayload,
    );
  }
}
