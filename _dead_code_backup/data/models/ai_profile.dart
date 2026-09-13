class AiProfile {
  final String id;
  final String name;
  final String provider; // openrouter, groq, openai, anthropic, gemini, custom
  final String apiKey;
  final String baseUrl;
  final String model;
  final bool isActive;

  AiProfile({
    required this.id,
    required this.name,
    required this.provider,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    this.isActive = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'provider': provider,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'isActive': isActive,
  };

  factory AiProfile.fromJson(Map<String, dynamic> json) => AiProfile(
    id: json['id'],
    name: json['name'],
    provider: json['provider'],
    apiKey: json['apiKey'],
    baseUrl: json['baseUrl'],
    model: json['model'],
    isActive: json['isActive'] ?? false,
  );

  AiProfile copyWith({
    String? id,
    String? name,
    String? provider,
    String? apiKey,
    String? baseUrl,
    String? model,
    bool? isActive,
  }) {
    return AiProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      isActive: isActive ?? this.isActive,
    );
  }
}
