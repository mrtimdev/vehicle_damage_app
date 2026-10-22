import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/damage_report.dart';
import '../providers/app_state.dart';
import '../utils/app_localizations.dart';
import 'report_screen.dart';

enum _HistoryFilter { all, hasSevere, cleanOnly, needsReview }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  _HistoryFilter _activeFilter = _HistoryFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(
      BuildContext context, DamageReport report, bool isKm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKm ? 'លុបរបាយការណ៍នេះ?' : 'Delete Report?'),
        content: Text(
          isKm
              ? 'របាយការណ៍វិភាគ និងរូបភាពដែលបានរក្សាទុកនេះនឹងត្រូវលុបចេញពីឧបករណ៍របស់អ្នក។'
              : 'This diagnostic report and its saved inspection photos will be permanently removed from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKm ? 'បោះបង់' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKm ? 'លុប' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(historyProvider.notifier).remove(report.id);
    }
  }

  Future<void> _confirmClearAll(
      BuildContext context, int count, bool isKm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKm ? 'លុបប្រវត្តិទាំងអស់?' : 'Clear All History?'),
        content: Text(
          isKm
              ? 'តើអ្នកពិតជាចង់លុបរបាយការណ៍ត្រួតពិនិត្យទាំងអស់ចំនួន $count មែនទេ?'
              : 'Are you sure you want to delete all $count saved vehicle inspection reports?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKm ? 'បោះបង់' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKm ? 'លុបទាំងអស់' : 'Clear All'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(historyProvider.notifier).clearAll();
    }
  }

  List<DamageReport> _filterReports(List<DamageReport> reports) {
    final q = _query.trim().toLowerCase();
    return reports.where((r) {
      switch (_activeFilter) {
        case _HistoryFilter.all:
          break;
        case _HistoryFilter.hasSevere:
          if (r.severeCount == 0) return false;
        case _HistoryFilter.cleanOnly:
          if (r.items.isNotEmpty) return false;
        case _HistoryFilter.needsReview:
          if (!r.hasLowConfidenceItems) return false;
      }

      if (q.isEmpty) return true;
      final inSummary = (r.summary ?? '').toLowerCase().contains(q) ||
          (r.summaryKhmer ?? '').toLowerCase().contains(q);
      final inProvider = r.providerLabel.toLowerCase().contains(q) ||
          r.modelUsed.toLowerCase().contains(q);
      final inItems = r.items.any(
        (i) =>
            i.partName.toLowerCase().contains(q) ||
            i.partNameKhmer.toLowerCase().contains(q) ||
            i.damageType.toLowerCase().contains(q) ||
            i.resolvedDamageTypeKhmer.toLowerCase().contains(q) ||
            (i.notes ?? '').toLowerCase().contains(q) ||
            i.resolvedNotesKhmer.toLowerCase().contains(q),
      );
      return inSummary || inProvider || inItems;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyProvider);
    final lang = ref.watch(appLanguageProvider);
    final strings = ref.watch(appStringsProvider);
    final isKm = lang.isKhmer;
    final dateFormat = DateFormat('MMM d, y · h:mm a');
    final reportsList = historyState.valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.historyTitle),
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
          if (reportsList.isNotEmpty)
            TextButton.icon(
              onPressed: () =>
                  _confirmClearAll(context, reportsList.length, isKm),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text(strings.clearAll),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            tooltip: 'Refresh History',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.read(historyProvider.notifier).refresh(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: historyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading history: $e'),
          ),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return _buildEmptyState(context, strings);
          }

          final filtered = _filterReports(reports);
          final totalDefects =
              reports.fold<int>(0, (sum, r) => sum + r.items.length);
          final avgConfidence = reports.isEmpty
              ? 0.0
              : reports.fold<double>(
                      0.0, (sum, r) => sum + r.overallConfidence) /
                  reports.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    _buildSummaryBanner(
                      context,
                      totalReports: reports.length,
                      totalDefects: totalDefects,
                      avgConfidence: avgConfidence,
                      strings: strings,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: strings.searchHistoryHint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(strings.filterAll(reports.length)),
                            selected: _activeFilter == _HistoryFilter.all,
                            onSelected: (_) => setState(
                                () => _activeFilter = _HistoryFilter.all),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: Text(strings.filterSevereFaults),
                            selected: _activeFilter == _HistoryFilter.hasSevere,
                            selectedColor: Colors.red.withValues(alpha: 0.16),
                            onSelected: (_) => setState(() => _activeFilter =
                                _activeFilter == _HistoryFilter.hasSevere
                                    ? _HistoryFilter.all
                                    : _HistoryFilter.hasSevere),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: Text(strings.filterCleanOnly),
                            selected: _activeFilter == _HistoryFilter.cleanOnly,
                            selectedColor: Colors.green.withValues(alpha: 0.16),
                            onSelected: (_) => setState(() => _activeFilter =
                                _activeFilter == _HistoryFilter.cleanOnly
                                    ? _HistoryFilter.all
                                    : _HistoryFilter.cleanOnly),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: Text(strings.filterNeedsReview),
                            selected:
                                _activeFilter == _HistoryFilter.needsReview,
                            selectedColor:
                                Colors.orange.withValues(alpha: 0.16),
                            onSelected: (_) => setState(() => _activeFilter =
                                _activeFilter == _HistoryFilter.needsReview
                                    ? _HistoryFilter.all
                                    : _HistoryFilter.needsReview),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_outlined,
                                size: 40,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                strings.emptyFilterMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _query = '';
                                    _activeFilter = _HistoryFilter.all;
                                  });
                                },
                                child: Text(strings.resetBtn),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final r = filtered[i];
                          return _buildReportCard(
                              context, r, dateFormat, strings, isKm);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryBanner(
    BuildContext context, {
    required int totalReports,
    required int totalDefects,
    required double avgConfidence,
    required AppStrings strings,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(
          children: [
            Expanded(
              child: _buildKpiItem(
                context,
                label: strings.kpiInspections,
                value: '$totalReports',
                icon: Icons.fact_check_outlined,
                color: scheme.primary,
              ),
            ),
            Container(width: 1, height: 32, color: scheme.outlineVariant),
            Expanded(
              child: _buildKpiItem(
                context,
                label: strings.kpiDefectsLogged,
                value: '$totalDefects',
                icon: Icons.build_circle_outlined,
                color: Colors.orange.shade800,
              ),
            ),
            Container(width: 1, height: 32, color: scheme.outlineVariant),
            Expanded(
              child: _buildKpiItem(
                context,
                label: strings.kpiAvgConfidence,
                value: '${(avgConfidence * 100).round()}%',
                icon: Icons.verified_outlined,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    DamageReport r,
    DateFormat dateFormat,
    AppStrings strings,
    bool isKm,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final thumbFile = File(r.sourceMediaPath);
    final hasThumb = r.sourceMediaPath.isNotEmpty && thumbFile.existsSync();
    final photoCount = r.allMediaPaths.length;

    final displaySummary =
        isKm ? r.resolvedSummaryKhmer : (r.summary ?? r.resolvedSummaryKhmer);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReportScreen(report: r)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: hasThumb
                          ? Image.file(
                              thumbFile,
                              width: 72,
                              height: 72,
                              cacheWidth: 200,
                              gaplessPlayback: true,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: scheme.surface,
                              child: Icon(
                                Icons.directions_car_outlined,
                                color: scheme.onSurfaceVariant,
                                size: 28,
                              ),
                            ),
                    ),
                    if (photoCount > 1)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$photoCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.items.isEmpty
                                ? strings.cleanVehicleInspection
                                : strings.defectsDetectedCount(r.items.length),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        Text(
                          '${(r.overallConfidence * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (displaySummary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        displaySummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (r.severeCount > 0)
                          _buildBadge(
                            isKm
                                ? '${r.severeCount} ធ្ងន់ធ្ងរ'
                                : '${r.severeCount} Severe',
                            Colors.red.shade700,
                          ),
                        if (r.moderateCount > 0)
                          _buildBadge(
                            isKm
                                ? '${r.moderateCount} មធ្យម'
                                : '${r.moderateCount} Moderate',
                            Colors.orange.shade800,
                          ),
                        if (r.minorCount > 0)
                          _buildBadge(
                            isKm
                                ? '${r.minorCount} ស្រាល'
                                : '${r.minorCount} Minor',
                            Colors.amber.shade700,
                          ),
                        if (r.items.isEmpty)
                          _buildBadge(
                              strings.noFaultsBadge, Colors.green.shade700),
                        Text(
                          '${r.modelUsed} · ${dateFormat.format(r.createdAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete Report',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline,
                    size: 19, color: scheme.onSurfaceVariant),
                onPressed: () => _confirmDelete(context, r, isKm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppStrings strings) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_toggle_off_outlined,
                size: 42,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.emptyHistoryTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.emptyHistorySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(homeTabIndexProvider.notifier).state = 0,
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              label: Text(strings.startFirstInspectionBtn),
            ),
          ],
        ),
      ),
    );
  }
}
