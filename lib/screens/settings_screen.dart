import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_provider_config.dart';
import '../providers/app_state.dart';
import '../providers/custom_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AIProviderKind _kind = AIProviderKind.openai;
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _obscureKey = true;
  bool _initialized = false;
  bool _loadingModels = false;
  String? _modelLoadError;
  List<String> _availableModels = const [];

  void _initFromConfig(AIProviderConfig? config) {
    if (_initialized) return;
    if (config != null) {
      _kind = config.kind;
      _baseUrlController.text = config.baseUrl;
      _apiKeyController.text = config.apiKey;
      _modelController.text = config.model;
    } else {
      _applyDefaultsForKind(_kind);
    }
    _initialized = true;
  }

  void _applyDefaultsForKind(AIProviderKind kind) {
    final defaults = AIProviderConfig.defaultsFor(kind);
    _baseUrlController.text = defaults.baseUrl;
    _modelController.text = defaults.model;
  }

  Future<void> _save() async {
    final config = AIProviderConfig(
      kind: _kind,
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
    );
    await ref.read(aiConfigProvider.notifier).update(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI provider settings saved.')),
      );
    }
  }

  Future<void> _loadModels() async {
    final baseUrl = _baseUrlController.text.trim();
    if (baseUrl.isEmpty) {
      setState(() => _modelLoadError = 'Enter a base URL first.');
      return;
    }

    setState(() {
      _loadingModels = true;
      _modelLoadError = null;
    });
    try {
      final models = await CustomProvider(AIProviderConfig(
        kind: AIProviderKind.custom,
        baseUrl: baseUrl,
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(),
      )).loadModels();
      if (!mounted) return;
      setState(() {
        _availableModels = models;
        if (models.isNotEmpty && !models.contains(_modelController.text)) {
          _modelController.text = models.first;
        }
        if (models.isEmpty) {
          _modelLoadError = 'No models were returned by the provider.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _modelLoadError = 'Could not load models: $e');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(aiConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Provider Settings')),
      body: configState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading settings: $e')),
        data: (config) {
          _initFromConfig(config);
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Provider',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<AIProviderKind>(
                  value: _kind,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  items: AIProviderKind.values
                      .map((k) =>
                          DropdownMenuItem(value: k, child: Text(k.label)))
                      .toList(),
                  onChanged: (k) {
                    if (k == null) return;
                    setState(() {
                      _kind = k;
                      _applyDefaultsForKind(k);
                      _availableModels = const [];
                      _modelLoadError = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text('Base URL',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'https://api.example.com/v1',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                Text('API Key', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: 'sk-...',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKey
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Model', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _availableModels.isEmpty
                          ? TextField(
                              controller: _modelController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'e.g. llama-3.2-11b-vision-instruct',
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _availableModels
                                      .contains(_modelController.text)
                                  ? _modelController.text
                                  : null,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder()),
                              hint: const Text('Select a model'),
                              items: _availableModels
                                  .map((model) => DropdownMenuItem(
                                      value: model, child: Text(model)))
                                  .toList(),
                              onChanged: (model) {
                                if (model != null) {
                                  _modelController.text = model;
                                }
                              },
                            ),
                    ),
                    if (_kind == AIProviderKind.custom) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Load models',
                        onPressed: _loadingModels ? null : _loadModels,
                        icon: _loadingModels
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                      ),
                    ],
                  ],
                ),
                if (_kind == AIProviderKind.custom &&
                    _modelLoadError != null) ...[
                  const SizedBox(height: 6),
                  Text(_modelLoadError!,
                      style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 8),
                Text(
                  'Stored securely on-device (Keychain / Keystore). Never sent anywhere except '
                  'directly to the base URL you configure above.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Settings'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(aiConfigProvider.notifier).clear();
                    setState(() => _initialized = false);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear Configuration'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
