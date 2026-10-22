import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/damage_report.dart';
import '../providers/app_state.dart';
import '../services/tts_service.dart';
import '../utils/app_localizations.dart';
import '../widgets/part_crop_viewer.dart';
import '../widgets/vehicle_media_players.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final DamageReport report;
  const ReportScreen({super.key, required this.report});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  DamageSeverity? _selectedSeverityFilter;
  int _currentImageIndex = 0;
  bool _showSummaryAltLang = false;
  bool _showAllItemsAltLang = false;
  final Set<int> _expandedItemAltLang = <int>{};
  bool _isVideoContentExpanded = false;
  bool _isSoundAnalysisExpanded = false;

  @override
  void dispose() {
    // Stop any active audio readout when leaving the report screen
    try {
      ref.read(ttsControllerProvider.notifier).stop();
    } catch (_) {}
    super.dispose();
  }

  Color _severityColor(DamageSeverity s) {
    switch (s) {
      case DamageSeverity.minor:
        return Colors.amber.shade700;
      case DamageSeverity.moderate:
        return Colors.orange.shade800;
      case DamageSeverity.severe:
        return Colors.red.shade700;
      case DamageSeverity.unknown:
        return Colors.blueGrey;
    }
  }

  IconData _damageTypeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('sound') ||
        t.contains('knock') ||
        t.contains('squeal') ||
        t.contains('tick') ||
        t.contains('acoustic')) {
      return Icons.graphic_eq_rounded;
    }
    if (t.contains('glass') || t.contains('crack') || t.contains('windshield')) {
      return Icons.broken_image_outlined;
    }
    if (t.contains('light') || t.contains('lamp') || t.contains('mirror')) {
      return Icons.highlight_outlined;
    }
    if (t.contains('rust') || t.contains('corrosion')) {
      return Icons.grain_outlined;
    }
    if (t.contains('misalign') || t.contains('gap')) {
      return Icons.compare_arrows_outlined;
    }
    if (t.contains('scratch') || t.contains('paint')) {
      return Icons.gesture_outlined;
    }
    return Icons.car_crash_outlined;
  }

  void _shareReport(AppLanguage lang) {
    final dateStr =
        DateFormat('MMM d, y · h:mm a').format(widget.report.createdAt);
    final buffer = StringBuffer();
    buffer.writeln('🚗 របាយការណ៍វិភាគរថយន្ត និងសំឡេងម៉ាស៊ីន / VEHICLE & SOUND ANALYSIS REPORT');
    buffer.writeln(
        'ប្រព័ន្ធ AI: ${widget.report.providerLabel} (${widget.report.modelUsed})');
    buffer.writeln(
        'ភាពត្រឹមត្រូវរួម (Confidence): ${(widget.report.overallConfidence * 100).toStringAsFixed(0)}%');
    buffer.writeln('កាលបរិច្ឆេទ (Date): $dateStr');

    final identity = widget.report.vehicleIdentity;
    if (identity != null && !identity.isEmpty) {
      buffer.writeln();
      buffer.writeln('🔍 អត្តសញ្ញាណរថយន្ត / Vehicle Specifications:');
      buffer.writeln('• ម៉ាក និងម៉ូដែល: ${identity.displayName}');
      if (identity.bodyType != null) {
        buffer.writeln('• ប្រភេទតួ: ${identity.bodyTypeKhmer ?? identity.bodyType}');
      }
      if (identity.color != null) {
        buffer.writeln('• ពណ៌: ${identity.colorKhmer ?? identity.color}');
      }
      if (identity.licensePlate != null) {
        buffer.writeln('• ស្លាកលេខ (Plate): ${identity.licensePlate}');
      }
      if (identity.vin != null) {
        buffer.writeln('• លេខតួ (VIN): ${identity.vin}');
      }
      if (identity.odometerReading != null) {
        buffer.writeln('• ចម្ងាយ (Odometer): ${identity.odometerReading} km');
      }
    }

    final health = widget.report.healthAssessment;
    if (health != null) {
      buffer.writeln();
      buffer.writeln('📊 ពិន្ទុ និងស្ថានភាពទូទៅ / Health Assessment:');
      buffer.writeln('• ពិន្ទុ (Score): ${health.conditionScore}/100 [Grade ${health.conditionGrade}]');
      buffer.writeln('• សុវត្ថិភាពបើកបរ (Roadworthiness): ${health.roadworthinessKhmer ?? health.roadworthiness}');
      if (health.repairCostTier != null) {
        buffer.writeln('• កម្រិតការជួសជុល: ${health.repairCostTierKhmer ?? health.repairCostTier}');
      }
    }

    final acoustic = widget.report.acousticAnalysis;
    if (acoustic != null && acoustic.audioTrackDetected) {
      buffer.writeln();
      buffer.writeln('🔊 ការវិភាគសំឡេងម៉ាស៊ីន / Sound Analysis:');
      buffer.writeln('• ពិន្ទុគុណភាពសំឡេង: ${acoustic.acousticHealthScore}%');
      buffer.writeln('• ទម្រង់សំឡេង: ${acoustic.engineSoundProfileKhmer.isNotEmpty ? acoustic.engineSoundProfileKhmer : acoustic.engineSoundProfile}');
      if (acoustic.audioSummaryKhmer != null && acoustic.audioSummaryKhmer!.isNotEmpty) {
        buffer.writeln('• សង្ខេបសំឡេង (ខ្មែរ): ${acoustic.audioSummaryKhmer}');
      }
      if (acoustic.anomalies.isNotEmpty) {
        buffer.writeln('• បញ្ហាសំឡេងរកឃើញ (${acoustic.anomalies.length}):');
        for (final a in acoustic.anomalies) {
          buffer.writeln('  - [${a.severity.labelKhmer}] ${a.anomalyTypeKhmer.isNotEmpty ? a.anomalyTypeKhmer : a.anomalyType} (${a.timestampSeconds}s): ${a.diagnosticAdviceKhmer.isNotEmpty ? a.diagnosticAdviceKhmer : a.diagnosticAdvice}');
        }
      }
    }

    buffer.writeln();
    final summaryKm = widget.report.resolvedSummaryKhmer;
    if (summaryKm.isNotEmpty) {
      buffer.writeln('សង្ខេប (ខ្មែរ): $summaryKm');
    }
    if (widget.report.summary != null && widget.report.summary!.isNotEmpty) {
      buffer.writeln('Summary (EN): ${widget.report.summary}');
    }
    buffer.writeln();
    buffer.writeln('លទ្ធផលរកឃើញ / Findings (${widget.report.items.length}):');
    if (widget.report.items.isEmpty) {
      buffer.writeln(
          '• មិនរកឃើញការខូចខាតផ្នែកខាងក្រៅទេ (No visible exterior defects detected).');
    } else {
      for (int i = 0; i < widget.report.items.length; i++) {
        final item = widget.report.items[i];
        final partKm = item.resolvedPartNameKhmer;
        final partTitle =
            partKm.isNotEmpty ? '$partKm (${item.partName})' : item.partName;
        buffer.writeln(
            '${i + 1}. [${item.severity.labelKhmer} / ${item.severity.label.toUpperCase()}] $partTitle');
        buffer.writeln(
            '   ប្រភេទកំហុស (Defect): ${item.resolvedDamageTypeKhmer} (${item.formattedDamageType})');
        buffer.writeln('   ការពិពណ៌នា (ខ្មែរ): ${item.resolvedNotesKhmer}');
        if (item.notes != null && item.notes!.isNotEmpty) {
          buffer.writeln('   Description (EN): ${item.notes}');
        }
        buffer.writeln(
            '   ភាពត្រឹមត្រូវ (Confidence): ${(item.confidence * 100).toStringAsFixed(0)}%');
      }
    }
    Share.share(buffer.toString(), subject: 'Vehicle Fault Diagnostic Report');
  }

  void _previewMedia(String path) {
    final file = File(path);
    if (!file.existsSync()) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.5,
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a compact, high-contrast Listen / Stop pill button for Khmer (`km`)
  /// or English (`en`) audio readout.
  Widget _buildListenChip({
    required BuildContext context,
    required TtsState ttsState,
    required String speechId,
    required String textToSpeak,
    required String langCode,
    required String label,
    required String stopLabel,
    String? keyName,
    VoidCallback? onActivated,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isThisActive = ttsState.isActive(speechId);
    final isThisLoading = ttsState.activeId == speechId && ttsState.isLoading;
    final isKmBtn = langCode == 'km';

    final activeColor = isKmBtn ? scheme.primary : Colors.teal.shade700;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: keyName != null ? Key(keyName) : null,
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (!isThisActive && onActivated != null) {
            onActivated();
          }
          ref.read(ttsControllerProvider.notifier).toggleSpeak(
                id: speechId,
                text: textToSpeak,
                langCode: langCode,
              );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isThisActive
                ? activeColor.withValues(alpha: 0.16)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isThisActive
                  ? activeColor
                  : activeColor.withValues(alpha: 0.35),
              width: isThisActive ? 1.3 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isThisLoading)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: activeColor,
                  ),
                )
              else
                Icon(
                  isThisActive
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_rounded,
                  size: 15,
                  color: activeColor,
                ),
              const SizedBox(width: 5),
              Text(
                isThisActive ? '$stopLabel ($label)' : label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds an interactive pill button allowing the user to toggle showing/hiding
  /// the English (EN) label & description (or Khmer when in EN mode).
  Widget _buildToggleLangChip({
    required BuildContext context,
    required bool isExpanded,
    required String showLabel,
    required String hideLabel,
    required VoidCallback onTap,
    String? keyName,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final accentColor = Colors.indigo.shade600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: keyName != null ? Key(keyName) : null,
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isExpanded
                ? accentColor.withValues(alpha: 0.14)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isExpanded
                  ? accentColor
                  : scheme.outlineVariant,
              width: isExpanded ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpanded ? Icons.visibility_off_outlined : Icons.translate,
                size: 13.5,
                color: isExpanded ? accentColor : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                isExpanded ? hideLabel : showLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isExpanded ? accentColor : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final lang = ref.watch(appLanguageProvider);
    final strings = ref.watch(appStringsProvider);
    final ttsState = ref.watch(ttsControllerProvider);
    final isKm = lang.isKhmer;
    final scheme = Theme.of(context).colorScheme;

    ref.listen<TtsState>(ttsControllerProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final severeCount = report.severeCount;
    final moderateCount = report.moderateCount;
    final minorCount = report.minorCount;

    final existingMedia = report.mediaPaths
        .where((p) =>
            p.isNotEmpty &&
            File(p).existsSync() &&
            p != report.videoPath &&
            p != report.audioPath)
        .toList();

    final filteredItems = _selectedSeverityFilter == null
        ? report.items
        : report.items
            .where((i) => i.severity == _selectedSeverityFilter)
            .toList();

    final dateStr = DateFormat('MMM d, y · h:mm a').format(report.createdAt);

    final hasVideo = report.videoPath != null &&
        report.videoPath!.isNotEmpty &&
        File(report.videoPath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.diagnosticReportTitle),
            Text(
              dateStr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
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
          IconButton(
            tooltip: strings.shareReportTooltip,
            icon: const Icon(Icons.ios_share_outlined, size: 20),
            onPressed: () => _shareReport(lang),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          if (hasVideo) ...[
            _buildCollapsibleInspectionVideoCard(
              context,
              report.videoPath!,
              strings,
              isKm,
            ),
            const SizedBox(height: 14),
          ],
          if (existingMedia.isNotEmpty) ...[
            if (hasVideo) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  strings.extractedFramesHeader,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
            _buildMediaCarousel(context, existingMedia, strings),
            const SizedBox(height: 14),
          ],
          if (report.vehicleIdentity != null &&
              !report.vehicleIdentity!.isEmpty) ...[
            _buildVehicleIdentityCard(
              context,
              report.vehicleIdentity!,
              strings,
              isKm,
            ),
            const SizedBox(height: 14),
          ],
          if (report.healthAssessment != null) ...[
            _buildHealthScorecard(
              context,
              report.healthAssessment!,
              strings,
              isKm,
            ),
            const SizedBox(height: 14),
          ],
          if (report.acousticAnalysis != null) ...[
            _buildAcousticAnalysisCard(
              context,
              report.acousticAnalysis!,
              strings,
              isKm,
              ttsState,
            ),
            const SizedBox(height: 14),
          ],
          _buildMetricsOverview(
            context,
            severeCount: severeCount,
            moderateCount: moderateCount,
            minorCount: minorCount,
            isKm: isKm,
          ),
          const SizedBox(height: 14),
          _buildOverviewCard(context, report, strings, isKm, ttsState),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.detectedFindingsHeader(filteredItems.length),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (report.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _buildToggleLangChip(
                    context: context,
                    isExpanded: _showAllItemsAltLang,
                    showLabel: strings.showSecondaryLangBtn,
                    hideLabel: strings.hideSecondaryLangBtn,
                    keyName: 'toggle_en_all_items',
                    onTap: () {
                      setState(() {
                        _showAllItemsAltLang = !_showAllItemsAltLang;
                        if (_showAllItemsAltLang) {
                          for (int i = 1; i <= report.items.length; i++) {
                            _expandedItemAltLang.add(i);
                          }
                        } else {
                          _expandedItemAltLang.clear();
                        }
                      });
                    },
                  ),
                ),
              if (_selectedSeverityFilter != null)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _selectedSeverityFilter = null),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                  label: Text(
                    strings.showAllBtn,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          if (report.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(strings.filterAll(report.items.length)),
                    selected: _selectedSeverityFilter == null,
                    onSelected: (_) =>
                        setState(() => _selectedSeverityFilter = null),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(strings.filterSevere(severeCount)),
                    selected: _selectedSeverityFilter == DamageSeverity.severe,
                    selectedColor: Colors.red.withValues(alpha: 0.16),
                    onSelected: (_) => setState(() => _selectedSeverityFilter =
                        _selectedSeverityFilter == DamageSeverity.severe
                            ? null
                            : DamageSeverity.severe),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(strings.filterModerate(moderateCount)),
                    selected:
                        _selectedSeverityFilter == DamageSeverity.moderate,
                    selectedColor: Colors.orange.withValues(alpha: 0.16),
                    onSelected: (_) => setState(() => _selectedSeverityFilter =
                        _selectedSeverityFilter == DamageSeverity.moderate
                            ? null
                            : DamageSeverity.moderate),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(strings.filterMinor(minorCount)),
                    selected: _selectedSeverityFilter == DamageSeverity.minor,
                    selectedColor: Colors.amber.withValues(alpha: 0.18),
                    onSelected: (_) => setState(() => _selectedSeverityFilter =
                        _selectedSeverityFilter == DamageSeverity.minor
                            ? null
                            : DamageSeverity.minor),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (report.items.isEmpty)
            _buildCleanVehicleCard(context, strings)
          else if (filteredItems.isEmpty)
            _buildEmptyFilterCard(context, strings)
          else
            ...filteredItems.asMap().entries.map(
                  (entry) => _buildDefectItemCard(
                    context,
                    index: entry.key + 1,
                    item: entry.value,
                    lang: lang,
                    strings: strings,
                    ttsState: ttsState,
                  ),
                ),
          if (report.rawModelResponse != null &&
              report.rawModelResponse!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildRawResponseTile(context, report.rawModelResponse!, strings),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaCarousel(
    BuildContext context,
    List<String> mediaPaths,
    AppStrings strings,
  ) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              itemCount: mediaPaths.length,
              onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
              itemBuilder: (context, i) {
                final path = mediaPaths[i];
                return GestureDetector(
                  onTap: () => _previewMedia(path),
                  child: Image.file(
                    File(path),
                    height: 220,
                    width: double.infinity,
                    cacheWidth: 960,
                    gaplessPlayback: true,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
          if (mediaPaths.length > 1)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  strings.photoIndexBadge(
                      _currentImageIndex + 1, mediaPaths.length),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => _previewMedia(
                mediaPaths[_currentImageIndex.clamp(0, mediaPaths.length - 1)],
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.zoom_in, color: Colors.white, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      strings.tapToZoom,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleIdentityCard(
    BuildContext context,
    VehicleIdentity identity,
    AppStrings strings,
    bool isKm,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final bodyTypeStr = isKm
        ? (identity.bodyTypeKhmer?.isNotEmpty == true
            ? identity.bodyTypeKhmer!
            : KhmerAutomotiveTranslator.bodyTypeKhmer(identity.bodyType))
        : (identity.bodyType ?? 'Vehicle');

    final colorStr = isKm
        ? (identity.colorKhmer?.isNotEmpty == true
            ? identity.colorKhmer!
            : (identity.color ?? ''))
        : (identity.color ?? '');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.vehicleIdentityTitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        identity.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                if (identity.licensePlate != null &&
                    identity.licensePlate!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: scheme.outlineVariant,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      identity.licensePlate!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (bodyTypeStr.isNotEmpty)
                  _buildIdentityChip(
                    context,
                    icon: Icons.commute_outlined,
                    label: bodyTypeStr,
                  ),
                if (colorStr.isNotEmpty)
                  _buildIdentityChip(
                    context,
                    icon: Icons.palette_outlined,
                    label: colorStr,
                  ),
                if (identity.odometerReading != null &&
                    identity.odometerReading! > 0)
                  _buildIdentityChip(
                    context,
                    icon: Icons.speed_rounded,
                    label:
                        '${NumberFormat("#,###").format(identity.odometerReading)} km',
                  ),
                if (identity.vin != null && identity.vin!.isNotEmpty)
                  _buildIdentityChip(
                    context,
                    icon: Icons.fingerprint_rounded,
                    label: 'VIN: ${identity.vin}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScorecard(
    BuildContext context,
    VehicleHealthAssessment health,
    AppStrings strings,
    bool isKm,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final score = health.conditionScore;
    final scoreColor = score >= 80
        ? Colors.green.shade700
        : (score >= 60 ? Colors.orange.shade800 : Colors.red.shade700);

    final roadworthinessStr = isKm
        ? (health.roadworthinessKhmer?.isNotEmpty == true
            ? health.roadworthinessKhmer!
            : KhmerAutomotiveTranslator.roadworthinessKhmer(
                health.roadworthiness,
              ))
        : health.roadworthiness;

    final costTierStr = isKm
        ? (health.repairCostTierKhmer?.isNotEmpty == true
            ? health.repairCostTierKhmer!
            : (health.repairCostTier ?? ''))
        : (health.repairCostTier ?? '');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: (score / 100).clamp(0.0, 1.0),
                        strokeWidth: 5.5,
                        backgroundColor: scoreColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      ),
                    ),
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            strings.healthScoreTitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: scoreColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              'Grade ${health.conditionGrade}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: scoreColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roadworthinessStr,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scoreColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (costTierStr.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${strings.estimatedRepairTierLabel}: ',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      costTierStr,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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

  Widget _buildCollapsibleInspectionVideoCard(
    BuildContext context,
    String videoPath,
    AppStrings strings,
    bool isKm,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? scheme.primary.withValues(alpha: 0.25)
              : scheme.outlineVariant.withValues(alpha: 0.6),
          width: 1.1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('toggle_inspection_video_collapse_button'),
              onTap: () => setState(() => _isVideoContentExpanded = !_isVideoContentExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.movie_filter_outlined,
                        size: 20,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.inspectionVideoTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _isVideoContentExpanded
                                ? (isKm ? 'ចុចដើម្បីបង្រួម' : 'Tap to collapse video')
                                : (isKm ? 'ចុចដើម្បីមើលវីដេអូ' : 'Tap to expand video'),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'MP4',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Icon(
                      _isVideoContentExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isVideoContentExpanded) ...[
            const Divider(height: 1),
            VehicleVideoPlayerCard(
              videoPath: videoPath,
              title: null,
              autoPlay: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcousticAnalysisCard(
    BuildContext context,
    AcousticAnalysisResult acoustic,
    AppStrings strings,
    bool isKm,
    TtsState ttsState,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isTrackDetected = acoustic.audioTrackDetected;
    final score = acoustic.acousticHealthScore;
    final scoreColor = !isTrackDetected
        ? Colors.blueGrey
        : (score >= 80
            ? Colors.green.shade700
            : (score >= 60 ? Colors.orange.shade800 : Colors.red.shade700));

    final profileStr = !isTrackDetected
        ? strings.soundStatusSilent
        : (isKm
            ? (acoustic.engineSoundProfileKhmer.isNotEmpty
                ? acoustic.engineSoundProfileKhmer
                : KhmerAutomotiveTranslator.engineSoundProfileKhmer(
                    acoustic.engineSoundProfile,
                  ))
            : acoustic.engineSoundProfile);

    final summaryStr = isKm
        ? (acoustic.audioSummaryKhmer?.isNotEmpty == true
            ? acoustic.audioSummaryKhmer!
            : (acoustic.audioSummary ?? ''))
        : (acoustic.audioSummary ?? '');

    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Expandable / Collapsible Header Row (Default Collapsed)
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('toggle_acoustic_analysis_card'),
              onTap: () => setState(() => _isSoundAnalysisExpanded = !_isSoundAnalysisExpanded),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.tertiary.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        size: 20,
                        color: scheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.acousticAnalysisTitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            profileStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                          ),
                          if (!_isSoundAnalysisExpanded) ...[
                            const SizedBox(height: 1),
                            Text(
                              isKm
                                  ? 'ចុចដើម្បីមើលការវិភាគសំឡេងលម្អិត'
                                  : 'Tap to view sound analysis details',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up_rounded, size: 14, color: scoreColor),
                          const SizedBox(width: 4),
                          Text(
                            '$score%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _isSoundAnalysisExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Collapsible Content (Default Collapsed)
          if (_isSoundAnalysisExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (summaryStr.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        summaryStr,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (isTrackDetected && acoustic.anomalies.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.soundStatusNormal,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (acoustic.anomalies.isNotEmpty) ...[
                    Text(
                      strings.soundAnomaliesTitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...acoustic.anomalies.asMap().entries.map((entry) {
                      final index = entry.key;
                      final anomaly = entry.value;

                      final aTypeKhmer = anomaly.anomalyTypeKhmer.isNotEmpty
                          ? anomaly.anomalyTypeKhmer
                          : KhmerAutomotiveTranslator.acousticAnomalyKhmer(
                              anomaly.anomalyType,
                            );
                      final aTypeEn =
                          anomaly.anomalyType.replaceAll('_', ' ').toUpperCase();

                      final adviceKhmer = anomaly.diagnosticAdviceKhmer.isNotEmpty
                          ? anomaly.diagnosticAdviceKhmer
                          : anomaly.diagnosticAdvice;
                      final adviceEn = anomaly.diagnosticAdvice;

                      final aType = isKm ? aTypeKhmer : aTypeEn;
                      final advice = isKm ? adviceKhmer : adviceEn;
                      final sevColor = _severityColor(anomaly.severity);

                      final spokenKhmer = aTypeKhmer.isNotEmpty
                          ? (adviceKhmer.isNotEmpty ? '$aTypeKhmer។ $adviceKhmer' : aTypeKhmer)
                          : adviceKhmer;
                      final spokenEnglish =
                          adviceEn.isNotEmpty ? '$aTypeEn. $adviceEn' : aTypeEn;

                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: sevColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sevColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 16, color: sevColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    aType,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: sevColor,
                                    ),
                                  ),
                                ),
                                if (anomaly.timestampSeconds > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${anomaly.timestampSeconds.toStringAsFixed(1)}s',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (advice.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                advice,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Allow Listen KH / EN in Detected Sound Anomalies
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildListenChip(
                                  context: context,
                                  ttsState: ttsState,
                                  speechId: 'sound_anomaly_${index}_km',
                                  textToSpeak: spokenKhmer,
                                  langCode: 'km',
                                  label: strings.listenKhmerBtn,
                                  stopLabel: strings.stopListeningBtn,
                                  keyName: 'listen_sound_anomaly_${index}_km',
                                ),
                                _buildListenChip(
                                  context: context,
                                  ttsState: ttsState,
                                  speechId: 'sound_anomaly_${index}_en',
                                  textToSpeak: spokenEnglish,
                                  langCode: 'en',
                                  label: strings.listenEnglishBtn,
                                  stopLabel: strings.stopListeningBtn,
                                  keyName: 'listen_sound_anomaly_${index}_en',
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (widget.report.audioPath != null &&
                      widget.report.audioPath!.isNotEmpty &&
                      File(widget.report.audioPath!).existsSync()) ...[
                    const SizedBox(height: 12),
                    VehicleAudioPlayerBar(
                      audioPath: widget.report.audioPath!,
                      title: strings.playExtractedAudioBtn,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    DamageReport report,
    AppStrings strings,
    bool isKm,
    TtsState ttsState,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final confPct = (report.overallConfidence * 100).round();
    final confColor = confPct >= 75
        ? Colors.green.shade700
        : (confPct >= 55 ? Colors.orange.shade800 : Colors.red.shade700);

    final resolvedKmSummary = report.resolvedSummaryKhmer;
    final hasKmSummary = resolvedKmSummary.isNotEmpty;
    final enSummary = report.summary?.trim() ?? '';
    final hasEnSummary = enSummary.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome_outlined,
                      size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.providerLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        report.modelUsed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: confColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: confColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined, size: 14, color: confColor),
                      const SizedBox(width: 4),
                      Text(
                        strings.confidenceBadge(confPct),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: confColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((isKm && hasKmSummary) || (!isKm && hasEnSummary) || hasKmSummary) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: scheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.summarize_outlined,
                            size: 14, color: scheme.primary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            strings.summaryCardTitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isKm
                          ? resolvedKmSummary
                          : (hasEnSummary ? enSummary : resolvedKmSummary),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_showSummaryAltLang &&
                        ((isKm && hasEnSummary) || (!isKm && hasKmSummary))) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isKm ? 'EN' : 'ខ្មែរ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isKm ? 'English Summary' : 'សង្ខេបជាភាសាខ្មែរ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isKm ? enSummary : resolvedKmSummary,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            // Listen & Toggle EN Buttons for Summary
            if (hasKmSummary || hasEnSummary) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (hasKmSummary)
                    _buildListenChip(
                      context: context,
                      ttsState: ttsState,
                      speechId: 'summary_km',
                      textToSpeak: resolvedKmSummary,
                      langCode: 'km',
                      label: strings.listenKhmerBtn,
                      stopLabel: strings.stopListeningBtn,
                      keyName: 'listen_summary_km',
                      onActivated: !isKm
                          ? () => setState(() => _showSummaryAltLang = true)
                          : null,
                    ),
                  if (hasEnSummary)
                    _buildListenChip(
                      context: context,
                      ttsState: ttsState,
                      speechId: 'summary_en',
                      textToSpeak: enSummary,
                      langCode: 'en',
                      label: strings.listenEnglishBtn,
                      stopLabel: strings.stopListeningBtn,
                      keyName: 'listen_summary_en',
                      onActivated: isKm
                          ? () => setState(() => _showSummaryAltLang = true)
                          : null,
                    ),
                  if (hasKmSummary && hasEnSummary)
                    _buildToggleLangChip(
                      context: context,
                      isExpanded: _showSummaryAltLang,
                      showLabel: strings.showSecondaryLangBtn,
                      hideLabel: strings.hideSecondaryLangBtn,
                      keyName: 'toggle_en_summary',
                      onTap: () => setState(
                          () => _showSummaryAltLang = !_showSummaryAltLang),
                    ),
                ],
              ),
            ],
            if (report.hasLowConfidenceItems) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade800, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.lowConfidenceWarning,
                        style: const TextStyle(fontSize: 12, height: 1.4),
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

  Widget _buildCleanVehicleCard(BuildContext context, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded,
                color: Colors.green, size: 34),
          ),
          const SizedBox(height: 12),
          Text(
            strings.noDefectsTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            strings.noDefectsSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterCard(BuildContext context, AppStrings strings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.filter_list_off,
                size: 32,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              strings.emptyFilterMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _selectedSeverityFilter = null),
              child: Text(strings.showAllBtn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefectItemCard(
    BuildContext context, {
    required int index,
    required DamageItem item,
    required AppLanguage lang,
    required AppStrings strings,
    required TtsState ttsState,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final sevColor = _severityColor(item.severity);
    final pct = (item.confidence * 100).round();
    final isKm = lang.isKhmer;
    final showAltLang =
        _showAllItemsAltLang || _expandedItemAltLang.contains(index);

    final partNameKm = item.resolvedPartNameKhmer;
    final khmerDescription = item.resolvedNotesKhmer;
    final englishDescription = item.notes?.trim() ?? '';

    final spokenKhmer =
        KhmerAutomotiveTranslator.buildFindingSpeechKhmer(item, index: index);
    final spokenEnglish =
        KhmerAutomotiveTranslator.buildFindingSpeechEnglish(item, index: index);

    final isAcousticFinding = item.notes?.contains('Sound') == true ||
        item.notesKhmer?.contains('សំឡេង') == true ||
        item.partName.contains('Sound') ||
        item.partNameKhmer.contains('សំឡេង') ||
        item.damageType.contains('sound') ||
        item.damageType.contains('knock') ||
        item.damageType.contains('squeal') ||
        item.damageType.contains('tick');

    void toggleThisCardAltLang() {
      setState(() {
        if (showAltLang) {
          _expandedItemAltLang.remove(index);
          _showAllItemsAltLang = false;
        } else {
          _expandedItemAltLang.add(index);
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: sevColor.withValues(alpha: 0.35), width: 1.1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: #Index, Part Name, and Severity Pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$index',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: sevColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKm && partNameKm.isNotEmpty
                              ? partNameKm
                              : item.partName,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    height: 1.3,
                                  ),
                        ),
                        if (showAltLang) ...[
                          const SizedBox(height: 2),
                          Text(
                            isKm ? item.partName : partNameKm,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      showAltLang
                          ? (isKm
                              ? '${item.severity.labelKhmer} · ${item.severity.label}'
                              : '${item.severity.label} · ${item.severity.labelKhmer}')
                          : item.severity.localizedLabel(lang),
                      style: TextStyle(
                        color: sevColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Defect Category Chip + Toggle EN button
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_damageTypeIcon(item.damageType),
                            size: 15, color: scheme.primary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            showAltLang
                                ? (isKm
                                    ? '${item.resolvedDamageTypeKhmer} · ${item.formattedDamageType}'
                                    : '${item.formattedDamageType} · ${item.resolvedDamageTypeKhmer}')
                                : item.localizedDamageType(lang),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAcousticFinding)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.tertiary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: scheme.tertiary.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.graphic_eq_rounded,
                            size: 13,
                            color: scheme.tertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            strings.soundDetectedDefectBadge,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildToggleLangChip(
                    context: context,
                    isExpanded: showAltLang,
                    showLabel: strings.showSecondaryLangBtn,
                    hideLabel: strings.hideSecondaryLangBtn,
                    keyName: 'toggle_en_item_$index',
                    onTap: toggleThisCardAltLang,
                  ),
                  if (item.needsReview)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_outlined,
                              size: 13, color: Colors.orange.shade800),
                          const SizedBox(width: 4),
                          Text(
                            strings.verifyManuallyBadge,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              // Auto-cropped Part Preview (e.g. Tires, Hydraulic, Engine, Brakes, Body)
              PartCropThumbnail(
                item: item,
                report: widget.report,
                lang: lang,
                ttsState: ttsState,
              ),
              // Description / Notes along with Listen Khmer & Listen English audio buttons
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Listen toolbar for Khmer & English results
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.headphones_outlined,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              strings.descriptionLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildListenChip(
                              context: context,
                              ttsState: ttsState,
                              speechId: 'item_${index}_km',
                              textToSpeak: spokenKhmer,
                              langCode: 'km',
                              label: strings.listenKhmerBtn,
                              stopLabel: strings.stopListeningBtn,
                              keyName: 'listen_item_${index}_km',
                              onActivated: !isKm
                                  ? () => setState(
                                      () => _expandedItemAltLang.add(index))
                                  : null,
                            ),
                            _buildListenChip(
                              context: context,
                              ttsState: ttsState,
                              speechId: 'item_${index}_en',
                              textToSpeak: spokenEnglish,
                              langCode: 'en',
                              label: strings.listenEnglishBtn,
                              stopLabel: strings.stopListeningBtn,
                              keyName: 'listen_item_${index}_en',
                              onActivated: isKm
                                  ? () => setState(
                                      () => _expandedItemAltLang.add(index))
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isKm
                          ? khmerDescription
                          : (englishDescription.isNotEmpty
                              ? englishDescription
                              : khmerDescription),
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (showAltLang) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isKm ? 'EN' : 'ខ្មែរ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isKm
                                  ? '${item.partName} · ${item.formattedDamageType} (${item.severity.label})'
                                  : '$partNameKm · ${item.resolvedDamageTypeKhmer} (${item.severity.labelKhmer})',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((isKm && englishDescription.isNotEmpty) ||
                          (!isKm && khmerDescription.isNotEmpty)) ...[
                        const SizedBox(height: 5),
                        Text(
                          isKm ? englishDescription : khmerDescription,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    strings.confidenceLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: item.confidence.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: scheme.outlineVariant,
                        color: item.needsReview ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRawResponseTile(
    BuildContext context,
    String rawJson,
    AppStrings strings,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.data_object, size: 18, color: scheme.primary),
        title: Text(
          strings.rawPayloadTitle,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          strings.rawPayloadSubtitle,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: rawJson));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Raw JSON copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: Text(strings.copyJsonBtn,
                      style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                SelectableText(
                  rawJson,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsOverview(
    BuildContext context, {
    required int severeCount,
    required int moderateCount,
    required int minorCount,
    required bool isKm,
  }) {
    return Row(
      children: [
        _buildMetricCard(
          context,
          title: 'Severe',
          khmerTitle: 'ធ្ងន់ធ្ងរ',
          isKm: isKm,
          count: severeCount,
          severity: DamageSeverity.severe,
          color: Colors.red.shade700,
          icon: Icons.error_outline,
        ),
        const SizedBox(width: 8),
        _buildMetricCard(
          context,
          title: 'Moderate',
          khmerTitle: 'មធ្យម',
          isKm: isKm,
          count: moderateCount,
          severity: DamageSeverity.moderate,
          color: Colors.orange.shade800,
          icon: Icons.warning_amber_outlined,
        ),
        const SizedBox(width: 8),
        _buildMetricCard(
          context,
          title: 'Minor',
          khmerTitle: 'ស្រាល',
          isKm: isKm,
          count: minorCount,
          severity: DamageSeverity.minor,
          color: Colors.amber.shade700,
          icon: Icons.info_outline,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String khmerTitle,
    required bool isKm,
    required int count,
    required DamageSeverity severity,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _selectedSeverityFilter == severity;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _selectedSeverityFilter = isSelected ? null : severity;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isSelected ? 0.2 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: isSelected ? 0.8 : 0.25),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isKm ? khmerTitle : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
