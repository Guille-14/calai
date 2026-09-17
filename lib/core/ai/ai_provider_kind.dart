/// Proveedores de IA soportados por CalAI.
///
/// El identificador persistido es estable; el texto visible debe resolverse en
/// la UI para no mezclar configuración con traducciones.
enum AiProviderKind {
  ollama('ollama', 'Ollama'),
  google('google', 'Google Gemini'),
  openRouter('openrouter', 'OpenRouter');

  final String id;
  final String displayName;

  const AiProviderKind(this.id, this.displayName);

  static AiProviderKind fromId(String? value) {
    return AiProviderKind.values.firstWhere(
      (provider) => provider.id == value?.trim().toLowerCase(),
      orElse: () => AiProviderKind.ollama,
    );
  }
}
