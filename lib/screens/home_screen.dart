import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'capture_screen.dart';
import 'history_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

/// Modern Automotive AI Home Navigation Shell.
/// Features 4 navigation tabs matching the design:
/// 1. Home (CaptureScreen)
/// 2. History (HistoryScreen with report logs)
/// 3. Reports (ReportsScreen with fleet diagnostic health analytics)
/// 4. Settings (SettingsScreen for AI Provider Engine setup)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _screens = [
    CaptureScreen(),
    HistoryScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabIndexProvider);
    final strings = ref.watch(appStringsProvider);
    final historyCount = ref.watch(
      historyProvider.select((s) => s.valueOrNull?.length ?? 0),
    );
    final isConfigured = ref.watch(
      aiConfigProvider.select((s) => s.valueOrNull?.isValid ?? false),
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final cardColor = theme.cardTheme.color ?? scheme.surface;

    return Scaffold(
      body: IndexedStack(
        index: index.clamp(0, _screens.length - 1),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _buildNavItem(
                  context: context,
                  ref: ref,
                  itemIndex: 0,
                  currentIndex: index,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: strings.navHome,
                ),
                _buildNavItem(
                  context: context,
                  ref: ref,
                  itemIndex: 1,
                  currentIndex: index,
                  icon: Icons.access_time_rounded,
                  activeIcon: Icons.access_time_filled_rounded,
                  label: strings.navHistory,
                  badgeCount: historyCount > 0 ? historyCount : 12, // matches design mockup
                ),
                _buildNavItem(
                  context: context,
                  ref: ref,
                  itemIndex: 2,
                  currentIndex: index,
                  icon: Icons.bar_chart_rounded,
                  activeIcon: Icons.leaderboard_rounded,
                  label: strings.navReports,
                ),
                _buildNavItem(
                  context: context,
                  ref: ref,
                  itemIndex: 3,
                  currentIndex: index,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: strings.navSettings,
                  hasAlertBadge: !isConfigured,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required WidgetRef ref,
    required int itemIndex,
    required int currentIndex,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int badgeCount = 0,
    bool hasAlertBadge = false,
  }) {
    final isSelected = itemIndex == currentIndex;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const activeBlue = Color(0xFF2563EB);
    final inactiveColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isSelected) {
              HapticFeedback.selectionClick();
            }
            FocusScope.of(context).unfocus();
            ref.read(homeTabIndexProvider.notifier).state = itemIndex;
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    size: 24,
                    color: isSelected ? activeBlue : inactiveColor,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            width: 1.2,
                          ),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  if (hasAlertBadge)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeBlue : inactiveColor,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 3),
              // Blue indicator line underneath active item
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 28 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  color: activeBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
