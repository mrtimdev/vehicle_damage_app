/// Supported AI provider "kinds". CUSTOM lets the user point at any
/// OpenAI-compatible or self-hosted HTTP endpoint (baseUrl + apiKey).
enum AIProviderKind { openai, anthropic, gemini, custom }

extension AIProviderKindX on AIProviderKind {
  String get label {
    switch (this) {
      case AIProviderKind.openai:
        return 'OpenAI';
      case AIProviderKind.anthropic:
        return 'Anthropic (Claude)';
      case AIProviderKind.gemini:
        return 'Google Gemini';
      case AIProviderKind.custom:
        return 'Custom / Self-hosted';
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
        return 'claude-sonnet-4-6';
      case AIProviderKind.gemini:
        return 'gemini-1.5-flash';
      case AIProviderKind.custom:
        return '';
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
