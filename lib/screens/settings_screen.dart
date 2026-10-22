import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_provider_config.dart';
import '../models/inspection_scope.dart';
import '../providers/app_state.dart';
import '../providers/provider_factory.dart';
import '../utils/app_localizations.dart';
import '../widgets/inspection_scope_modal.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AIProviderKind _kind = AIProviderKind.gemini;
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _obscureKey = true;
  bool _initialized = false;
  bool _loadingModels = false;
  bool _customModelMode = false;
  String? _modelLoadError;
  String? _modelLoadSuccess;
  List<String> _availableModels = const [];

  IconData _providerIcon(AIProviderKind kind) {
    switch (kind) {
      case AIProviderKind.openai:
        return Icons.auto_awesome_mosaic_outlined;
      case AIProviderKind.anthropic:
        return Icons.psychology_outlined;
      case AIProviderKind.gemini:
        return Icons.diamond_outlined;
      case AIProviderKind.custom:
        return Icons.dns_outlined;
    }
  }

  void _initFromConfig(AIProviderConfig? config) {
    if (_initialized) return;
    if (config != null) {
      _kind = config.kind;
      _baseUrlController.text = config.baseUrl;
      _apiKeyController.text = config.apiKey;
      _modelController.text = config.model;
      final presets = _kind.suggestedModels;
      if (config.model.isNotEmpty && !presets.contains(config.model)) {
        _availableModels = [config.model, ...presets];
      } else {
        _availableModels = presets;
      }
    } else {
      _applyDefaultsForKind(_kind);
    }
    _initialized = true;
  }

  void _applyDefaultsForKind(AIProviderKind kind) {
    final defaults = AIProviderConfig.defaultsFor(kind);
    _baseUrlController.text = defaults.baseUrl;
    _modelController.text = defaults.model;
    _availableModels = kind.suggestedModels;
  }

  AIProviderConfig _buildCurrentConfig() {
    return AIProviderConfig(
      kind: _kind,
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
    );
  }

  Future<void> _pasteApiKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty && mounted) {
      setState(() {
        _apiKeyController.text = text;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final config = _buildCurrentConfig();
    await ref.read(aiConfigProvider.notifier).update(config);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade700,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved ${config.kind.shortLabel} (${config.model}) configuration.',
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Future<void> _loadModels() async {
    FocusScope.of(context).unfocus();
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (_kind == AIProviderKind.custom && baseUrl.isEmpty) {
      setState(() => _modelLoadError = 'Please enter a Base URL first.');
      return;
    }

    if (_kind != AIProviderKind.custom && apiKey.isEmpty) {
      setState(() =>
          _modelLoadError = 'Please enter your API Key first to fetch models.');
      return;
    }

    setState(() {
      _loadingModels = true;
      _modelLoadError = null;
      _modelLoadSuccess = null;
    });

    try {
      final config = _buildCurrentConfig();
      final models = await AIProviderFactory.fetchModels(config);
      if (!mounted) return;

      setState(() {
        if (models.isNotEmpty) {
          _availableModels = models;
          if (!models.contains(_modelController.text.trim())) {
            _modelController.text = models.first;
          }
          _modelLoadSuccess =
              'Connected · ${models.length} models loaded from ${_kind.shortLabel}';
          _customModelMode = false;
        } else {
          _modelLoadError = 'No models were returned by ${_kind.label}.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      String errStr = e.toString();
      if (errStr.contains('401') || errStr.contains('Unauthorized')) {
        errStr = 'Authentication failed (401). Please verify your API key.';
      } else if (errStr.contains('403') || errStr.contains('Forbidden')) {
        errStr = 'Access denied (403). Check API key permissions.';
      } else if (errStr.contains('404')) {
        errStr = 'Models endpoint not found (404). Check Base URL.';
      }
      setState(() => _modelLoadError = errStr);
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
    final savedConfig = configState.valueOrNull;
    final isSavedValid = savedConfig != null && savedConfig.isValid;
    final lang = ref.watch(appLanguageProvider);
    final strings = ref.watch(appStringsProvider);
    final isKm = lang.isKhmer;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.settingsTitle),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isSavedValid ? Colors.green : Colors.amber.shade700,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isSavedValid
                        ? (isKm
                            ? 'កំពុងប្រើ៖ ${savedConfig.kind.label} · ${savedConfig.model}'
                            : 'Active: ${savedConfig.kind.label} · ${savedConfig.model}')
                        : (isKm
                            ? 'ជ្រើសរើសប្រព័ន្ធ AI បញ្ចូល API Key និងរក្សាទុក'
                            : 'Select provider, enter API key & save'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: OutlinedButton.icon(
              onPressed: () => ref.read(appLanguageProvider.notifier).toggle(),
              icon: const Icon(Icons.translate, size: 15),
              label: Text(
                isKm ? 'ខ្មែរ' : 'EN',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
          if (savedConfig != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () async {
                  await ref.read(aiConfigProvider.notifier).clear();
                  setState(() {
                    _apiKeyController.clear();
                    _applyDefaultsForKind(_kind);
                    _modelLoadError = null;
                    _modelLoadSuccess = null;
                  });
                },
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text(strings.resetBtn),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: configState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading settings: $e')),
        data: (config) {
          _initFromConfig(config);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  cacheExtent: 1000,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    _buildProviderGridCard(context, strings),
                    const SizedBox(height: 12),
                    _buildCredentialsCard(context, strings, isKm),
                    const SizedBox(height: 12),
                    _buildModelSelectionCard(context, strings),
                    const SizedBox(height: 12),
                    _buildInspectionScopeSettingCard(context, strings, isKm),
                    const SizedBox(height: 12),
                    _buildAutoCropSettingCard(context, strings, isKm),
                    const SizedBox(height: 12),
                    _buildSecurityNote(context, strings),
                  ],
                ),
              ),
              _buildBottomSaveBar(context, strings),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProviderGridCard(BuildContext context, AppStrings strings) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.hub_outlined,
                      size: 17, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.aiProviderTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        strings.aiProviderSubtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: AIProviderKind.values.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 54,
              ),
              itemBuilder: (context, idx) {
                final k = AIProviderKind.values[idx];
                final selected = _kind == k;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (_kind == k) return;
                    setState(() {
                      _kind = k;
                      _applyDefaultsForKind(k);
                      _modelLoadError = null;
                      _modelLoadSuccess = null;
                      _customModelMode = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.1)
                          : scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selected ? scheme.primary : scheme.outlineVariant,
                        width: selected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _providerIcon(k),
                          size: 19,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                k.shortLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurface,
                                ),
                              ),
                              Text(
                                k.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle,
                              size: 15, color: scheme.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialsCard(
      BuildContext context, AppStrings strings, bool isKm) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.vpn_key_outlined,
                      size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.credentialsTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        isKm
                            ? 'កំណត់អាសយដ្ឋានភ្ជាប់ និងកូនសោសម្ងាត់ API Key'
                            : 'Configure connection endpoint and authentication token',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _baseUrlController,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                labelText: strings.baseUrlLabel,
                prefixIcon: const Icon(Icons.link, size: 20),
                hintText: _kind.defaultBaseUrl.isNotEmpty
                    ? _kind.defaultBaseUrl
                    : 'http://localhost:11434/v1',
                suffixIcon: _kind != AIProviderKind.custom
                    ? IconButton(
                        tooltip: strings.resetBtn,
                        icon: const Icon(Icons.restore, size: 19),
                        onPressed: () {
                          setState(() {
                            _baseUrlController.text = _kind.defaultBaseUrl;
                          });
                        },
                      )
                    : null,
              ),
              keyboardType: TextInputType.url,
            ),
            if (_kind == AIProviderKind.custom) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.bolt_rounded,
                        size: 14, color: Color(0xFF2563EB)),
                    label: const Text('SV Backend (Local: 8000)',
                        style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _baseUrlController.text = 'http://localhost:8000';
                        _modelController.text = 'multimodal-vehicle-analyzer';
                        if (!_availableModels
                            .contains('multimodal-vehicle-analyzer')) {
                          _availableModels.insert(
                              0, 'multimodal-vehicle-analyzer');
                        }
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.android_rounded,
                        size: 14, color: Colors.green),
                    label: const Text('SV Backend (Android: 10.0.2.2)',
                        style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _baseUrlController.text = 'http://10.0.2.2:8000';
                        _modelController.text = 'multimodal-vehicle-analyzer';
                        if (!_availableModels
                            .contains('multimodal-vehicle-analyzer')) {
                          _availableModels.insert(
                              0, 'multimodal-vehicle-analyzer');
                        }
                      });
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                labelText: _kind == AIProviderKind.custom
                    ? strings.apiKeyOptionalLabel
                    : strings.apiKeyRequiredLabel,
                prefixIcon: const Icon(Icons.key_outlined, size: 20),
                hintText: _kind == AIProviderKind.custom
                    ? (isKm
                        ? 'មិនចាំបាច់សម្រាប់ម៉ាស៊ីនផ្ទាល់ខ្លួន'
                        : 'Optional for local endpoints')
                    : (isKm
                        ? 'បិទភ្ជាប់ API Key របស់ ${_kind.shortLabel}'
                        : 'Paste your ${_kind.shortLabel} API key'),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: strings.pasteTooltip,
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      onPressed: _pasteApiKey,
                    ),
                    IconButton(
                      tooltip: _obscureKey ? 'Show API key' : 'Hide API key',
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                      ),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelectionCard(BuildContext context, AppStrings strings) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.memory_outlined,
                      size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.modelSelectionTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        strings.modelSelectionSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () =>
                      setState(() => _customModelMode = !_customModelMode),
                  icon: Icon(
                      _customModelMode ? Icons.list : Icons.edit_outlined,
                      size: 15),
                  label: Text(
                    _customModelMode ? strings.presetsBtn : strings.customIdBtn,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!_customModelMode)
              DropdownButtonFormField<String>(
                key: ValueKey(
                    'model_dropdown_${_kind.name}_${_availableModels.length}_${_modelController.text}'),
                isExpanded: true,
                initialValue:
                    _availableModels.contains(_modelController.text)
                        ? _modelController.text
                        : (_availableModels.isNotEmpty
                            ? _availableModels.first
                            : null),
                decoration: InputDecoration(
                  labelText: strings.activeModelLabel,
                  prefixIcon: const Icon(Icons.smart_toy_outlined, size: 20),
                ),
                items: _availableModels
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ))
                    .toList(),
                onChanged: (selected) {
                  if (selected != null) {
                    setState(() => _modelController.text = selected);
                  }
                },
              )
            else
              TextField(
                controller: _modelController,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: strings.customModelLabel,
                  prefixIcon: const Icon(Icons.code, size: 20),
                  hintText: 'e.g. gemini-2.0-flash, gpt-4o',
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadingModels ? null : _loadModels,
                icon: _loadingModels
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(
                  _loadingModels
                      ? strings.connectingToProvider(_kind.shortLabel)
                      : strings.loadModelsBtn,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
            if (_modelLoadSuccess != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.green.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _modelLoadSuccess!,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_modelLoadError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _modelLoadError!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInspectionScopeSettingCard(
    BuildContext context,
    AppStrings strings,
    bool isKm,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final scope = ref.watch(inspectionScopeProvider);
    final activeCount = scope.activeDefectTags.length;
    final allCount = InspectionScope.allDefectTags.length;

    return Card(
      child: ListTile(
        key: const Key('settings_inspection_scope_tile'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.tune_rounded, size: 18, color: scheme.primary),
        ),
        title: Text(
          strings.inspectionScopeSettingsTile,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        subtitle: Text(
          '${strings.translateArea(scope.selectedArea)} · ${activeCount == allCount ? strings.allTagsActive : strings.activeTagsCount(activeCount, allCount)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => showInspectionScopeModal(context, ref),
      ),
    );
  }

  Widget _buildAutoCropSettingCard(
    BuildContext context,
    AppStrings strings,
    bool isKm,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isAutoCropEnabled = ref.watch(autoCropPartsProvider);

    return Card(
      child: SwitchListTile(
        key: const Key('settings_auto_crop_parts_switch'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        secondary: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.crop_free_rounded, size: 18, color: scheme.primary),
        ),
        title: Text(
          strings.autoCropPartsTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        subtitle: Text(
          strings.autoCropPartsSubtitle,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
        value: isAutoCropEnabled,
        onChanged: (val) {
          ref.read(autoCropPartsProvider.notifier).setEnabled(val);
        },
      ),
    );
  }

  Widget _buildSecurityNote(BuildContext context, AppStrings strings) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.securityNote,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSaveBar(BuildContext context, AppStrings strings) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? scheme.surface;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_circle_outline, size: 20),
          label: Text(
            strings.saveSettingsBtn,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ),
    );
  }
}
