/// Supported AI provider "kinds". CUSTOM lets the user point at any
/// OpenAI-compatible or self-hosted HTTP endpoint (baseUrl + apiKey).
enum AIProviderKind { openai, anthropic, gemini, custom }

extension AIProviderKindX on AIProviderKind {
  String get label {
    switch (this) {
      case AIProviderKind.openai:
        return 'OpenAI';
      case AIProviderKind.anthropic:
        return 'Anthropic Claude';
      case AIProviderKind.gemini:
        return 'Google Gemini';
      case AIProviderKind.custom:
        return 'Custom Endpoint';
    }
  }

  String get shortLabel {
    switch (this) {
      case AIProviderKind.openai:
        return 'OpenAI';
      case AIProviderKind.anthropic:
        return 'Claude';
      case AIProviderKind.gemini:
        return 'Gemini';
      case AIProviderKind.custom:
        return 'Custom';
    }
  }

  String get subtitle {
    switch (this) {
      case AIProviderKind.openai:
        return 'GPT-4o & Vision Models';
      case AIProviderKind.anthropic:
        return 'Claude Sonnet & Haiku Vision';
      case AIProviderKind.gemini:
        return 'Gemini Flash & Pro Multimodal';
      case AIProviderKind.custom:
        return 'SV Vehicle AI Backend, Ollama, vLLM, Self-Hosted';
    }
  }

  /// Sensible default base URL per provider — user can override.
  String get defaultBaseUrl {
    switch (this) {
      case AIProviderKind.openai:
        return 'https://api.openai.com/v1';
      case AIProviderKind.anthropic:
        return 'https://api.anthropic.com/v1';
      case AIProviderKind.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case AIProviderKind.custom:
        return '';
    }
  }

  String get defaultModel {
    switch (this) {
      case AIProviderKind.openai:
        return 'gpt-4o-mini';
      case AIProviderKind.anthropic:
        return 'claude-3-7-sonnet-20250219';
      case AIProviderKind.gemini:
        return 'gemini-2.0-flash';
      case AIProviderKind.custom:
        return 'llama-3.2-11b-vision-instruct';
    }
  }

  /// Curated list of known vision-capable models for quick selection.
  List<String> get suggestedModels {
    switch (this) {
      case AIProviderKind.openai:
        return const [
          'gpt-4o-mini',
          'gpt-4o',
          'gpt-4.5-preview',
          'gpt-4-turbo',
          'o1',
          'o3-mini',
        ];
      case AIProviderKind.anthropic:
        return const [
          'claude-3-7-sonnet-20250219',
          'claude-3-5-sonnet-20241022',
          'claude-3-5-haiku-20241022',
          'claude-3-opus-20240229',
        ];
      case AIProviderKind.gemini:
        return const [
          'gemini-2.0-flash',
          'gemini-2.0-flash-lite-preview',
          'gemini-1.5-flash',
          'gemini-1.5-pro',
          'gemini-2.0-pro-exp-02-05',
        ];
      case AIProviderKind.custom:
        return const [
          'multimodal-vehicle-analyzer',
          'laion-clap-automotive',
          'echov2-anomaly-detector',
          'engine-sound-classifier',
          'clap-finetuned-custom',
          'llama-3.2-11b-vision-instruct',
          'llama-3.2-90b-vision-instruct',
          'llava-1.6-34b',
          'qwen2-vl-7b-instruct',
        ];
    }
  }
}

/// User-editable AI provider configuration, persisted to secure storage.
class AIProviderConfig {
  final AIProviderKind kind;
  final String baseUrl;
  final String apiKey;
  final String model;

  /// Extra headers some self-hosted / gateway providers require
  /// (e.g. `{"X-Org-Id": "abc"}`). Stored as a flat map.
  final Map<String, String> extraHeaders;

  const AIProviderConfig({
    required this.kind,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.extraHeaders = const {},
  });

  factory AIProviderConfig.defaultsFor(AIProviderKind kind) => AIProviderConfig(
        kind: kind,
        baseUrl: kind.defaultBaseUrl,
        apiKey: '',
        model: kind.defaultModel,
      );

  AIProviderConfig copyWith({
    AIProviderKind? kind,
    String? baseUrl,
    String? apiKey,
    String? model,
    Map<String, String>? extraHeaders,
  }) {
    return AIProviderConfig(
      kind: kind ?? this.kind,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      extraHeaders: extraHeaders ?? this.extraHeaders,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'extraHeaders': extraHeaders,
      };

  factory AIProviderConfig.fromJson(Map<String, dynamic> json) {
    return AIProviderConfig(
      kind: AIProviderKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => AIProviderKind.custom,
      ),
      baseUrl: json['baseUrl'] ?? '',
      apiKey: json['apiKey'] ?? '',
      model: json['model'] ?? '',
      extraHeaders: Map<String, String>.from(json['extraHeaders'] ?? {}),
    );
  }

  bool get isValid =>
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      (kind == AIProviderKind.custom || apiKey.trim().isNotEmpty);
}
