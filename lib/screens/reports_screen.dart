import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/damage_report.dart';
import '../providers/app_state.dart';
import '../utils/app_localizations.dart';
import 'report_screen.dart';

/// Reports & Vehicle Health Analytics Screen.
/// Corresponds to Tab 2 (Reports) in the bottom navigation bar.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    final strings = ref.watch(appStringsProvider);
    final isKm = strings.isKm;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isKm ? 'របាយការណ៍វិភាគ និងស្ថិតិ' : 'Diagnostic Reports & Analytics',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: OutlinedButton.icon(
              onPressed: () => ref.read(appLanguageProvider.notifier).toggle(),
              icon: const Icon(Icons.translate, size: 14),
              label: Text(
                isKm ? 'ខ្មែរ' : 'EN',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return _buildEmptyState(context, strings, isKm, ref);
          }
          return _buildReportsContent(
              context, reports, strings, isKm, scheme, isDark);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error: $err'),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppStrings strings,
    bool isKm,
    WidgetRef ref,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                size: 56,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isKm ? 'មិនទាន់មានរបាយការណ៍ទេ' : 'No Diagnostic Reports Yet',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              isKm
                  ? 'ថតរូប ឬបញ្ចូលវីដេអូរថយន្តដើម្បីបង្កើតរបាយការណ៍វិភាគ AI ដំបូងរបស់អ្នក។'
                  : 'Capture photos or record a vehicle clip to generate your first AI inspection report.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(homeTabIndexProvider.notifier).state = 0,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(isKm ? 'ចាប់ផ្តើមស្កេន' : 'Start Inspection'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsContent(
    BuildContext context,
    List<DamageReport> reports,
    AppStrings strings,
    bool isKm,
    ColorScheme scheme,
    bool isDark,
  ) {
    int totalDefects = 0;
    int severeCount = 0;
    int acousticAnomaliesCount = 0;
    int totalHealthScore = 0;
    int roadworthyCount = 0;

    for (final r in reports) {
      totalDefects += r.items.length;
      severeCount +=
          r.items.where((it) => it.severity == DamageSeverity.severe).length;
      if (r.hasAcousticAnomalies) {
        acousticAnomaliesCount +=
            r.acousticAnalysis?.anomalies.length ?? 0;
      }
      final score = r.healthAssessment?.conditionScore;
      if (score != null) {
        totalHealthScore += score;
      } else {
        totalHealthScore += (r.overallConfidence * 100).round();
      }
      if (r.healthAssessment?.isRoadworthy ?? true) {
        roadworthyCount++;
      }
    }

    final avgHealthScore =
        reports.isEmpty ? 100 : (totalHealthScore / reports.length).round();
    final safeRate =
        reports.isEmpty ? 100 : ((roadworthyCount / reports.length) * 100).round();

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // KPI Grid
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: isKm ? 'ការត្រួតពិនិត្យ' : 'Total Inspections',
                value: '${reports.length}',
                icon: Icons.assignment_outlined,
                accentColor: const Color(0xFF2563EB),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: isKm ? 'សុវត្ថិភាពទូទៅ' : 'Safe / Roadworthy',
                value: '$safeRate%',
                icon: Icons.verified_user_outlined,
                accentColor: Colors.green,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: isKm ? 'កំហុសធ្ងន់ធ្ងរ' : 'Severe Faults',
                value: '$severeCount',
                icon: Icons.warning_amber_rounded,
                accentColor: Colors.red.shade600,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: isKm ? 'សំឡេងមិនប្រក្រតី' : 'Acoustic Faults',
                value: '$acousticAnomaliesCount',
                icon: Icons.graphic_eq_rounded,
                accentColor: const Color(0xFFDB2777),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Health Score Gauge Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: avgHealthScore >= 80
                        ? [Colors.green.shade400, Colors.green.shade700]
                        : (avgHealthScore >= 60
                            ? [Colors.amber.shade400, Colors.amber.shade700]
                            : [Colors.red.shade400, Colors.red.shade700]),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$avgHealthScore',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKm
                          ? 'ពិន្ទុសុខភាពរថយន្តមធ្យម'
                          : 'Fleet Average Health Score',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isKm
                          ? 'បានរកឃើញកំហុសសរុបចំនួន $totalDefects កន្លែងក្នុងរបាយការណ៍ទាំងអស់។'
                          : 'Detected $totalDefects vehicle defect(s) across all generated reports.',
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
        ),
        const SizedBox(height: 20),

        // Recent Reports Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isKm ? 'របាយការណ៍ថ្មីៗ' : 'Recent Diagnostic Reports',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              '${reports.length} ${isKm ? "របាយការណ៍" : "Report(s)"}',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Report Cards
        ...reports.map((report) {
          final conditionScore =
              report.healthAssessment?.conditionScore ??
                  (report.overallConfidence * 100).round();
          final title = report.vehicleIdentity?.displayName.isNotEmpty == true
              ? report.vehicleIdentity!.displayName
              : (isKm ? 'ការត្រួតពិនិត្យរថយន្ត' : 'Vehicle Inspection');

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReportScreen(report: report),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormat.format(report.createdAt),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (report.hasAcousticAnomalies) ...[
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 13,
                                  color: Color(0xFFDB2777),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isKm ? 'មានសំឡេងម៉ាស៊ីន' : 'Acoustic Sound Track',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFDB2777),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: conditionScore >= 80
                            ? Colors.green.withValues(alpha: 0.12)
                            : (conditionScore >= 60
                                ? Colors.amber.withValues(alpha: 0.14)
                                : Colors.red.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$conditionScore%',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: conditionScore >= 80
                              ? Colors.green.shade700
                              : (conditionScore >= 60
                                  ? Colors.amber.shade800
                                  : Colors.red.shade700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
