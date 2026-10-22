import 'ai_provider.dart';
import 'openai_provider.dart';
import 'anthropic_provider.dart';
import 'gemini_provider.dart';
import 'custom_provider.dart';

/// Single place that maps a stored [AIProviderConfig] to the concrete
/// adapter that knows how to talk to it. Add new providers here.
class AIProviderFactory {
  static AIProvider build(AIProviderConfig config) {
    switch (config.kind) {
      case AIProviderKind.openai:
        return OpenAIProvider(config);
      case AIProviderKind.anthropic:
        return AnthropicProvider(config);
      case AIProviderKind.gemini:
        return GeminiProvider(config);
      case AIProviderKind.custom:
        return CustomProvider(config);
    }
  }

  /// Convenience method to query available models for a given configuration.
  static Future<List<String>> fetchModels(AIProviderConfig config) {
    final provider = build(config);
    return provider.loadModels();
  }
}
