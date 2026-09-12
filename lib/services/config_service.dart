import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/ai_provider_config.dart';

/// Persists the user's AI provider configuration (base URL, API key,
/// model, kind) using the platform secure keystore/keychain — API keys
/// should never sit in plain SharedPreferences.
class ConfigService {
  static const _key = 'ai_provider_config';
  final _storage = const FlutterSecureStorage();

  Future<void> save(AIProviderConfig config) async {
    await _storage.write(key: _key, value: jsonEncode(config.toJson()));
  }

  Future<AIProviderConfig?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return AIProviderConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
