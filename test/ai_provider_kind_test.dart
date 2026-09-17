import 'package:flutter_test/flutter_test.dart';

import 'package:calorie_lens/core/ai/ai_provider_kind.dart';

void main() {
  group('AiProviderKind', () {
    test('normaliza identificadores persistidos', () {
      expect(AiProviderKind.fromId('GOOGLE'), AiProviderKind.google);
      expect(AiProviderKind.fromId('openrouter'), AiProviderKind.openRouter);
    });

    test('usa Ollama como fallback seguro', () {
      expect(AiProviderKind.fromId(null), AiProviderKind.ollama);
      expect(AiProviderKind.fromId('provider-that-does-not-exist'),
          AiProviderKind.ollama);
    });
  });
}
