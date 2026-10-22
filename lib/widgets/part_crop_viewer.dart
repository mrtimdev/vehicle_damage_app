import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/damage_report.dart';
import '../providers/app_state.dart';
import '../services/tts_service.dart';
import '../utils/app_localizations.dart';

/// Interactive thumbnail widget displaying an auto-cropped component image
/// (e.g., Tires, Hydraulic lines, Engine components, Dents, Scratches).
/// Respects the user's [autoCropPartsProvider] setting.
class PartCropThumbnail extends ConsumerWidget {
  final DamageItem item;
  final DamageReport report;
  final AppLanguage lang;
  final TtsState? ttsState;

  const PartCropThumbnail({
    super.key,
    required this.item,
    required this.report,
    required this.lang,
    this.ttsState,
  });

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

  IconData _categoryIcon() {
    if (item.isTire) return Icons.tire_repair_rounded;
    if (item.isHydraulic) return Icons.precision_manufacturing_rounded;
    if (item.isMechanicalEngine) return Icons.engineering_rounded;
    if (item.isBrake) return Icons.disc_full_rounded;
    return Icons.car_repair_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAutoCropEnabled = ref.watch(autoCropPartsProvider);
    if (!isAutoCropEnabled) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isKm = lang.isKhmer;
    final sevColor = _severityColor(item.severity);
    final categoryStr = item.componentCategory(isKhmer: isKm);

    final hasCropFile = item.croppedImagePath != null &&
        item.croppedImagePath!.isNotEmpty &&
        File(item.croppedImagePath!).existsSync();

    final sourcePath = (report.allMediaPaths.isNotEmpty &&
            item.imageIndex < report.allMediaPaths.length)
        ? report.allMediaPaths[item.imageIndex]
        : (report.allMediaPaths.isNotEmpty ? report.allMediaPaths.first : null);

    final hasSourceFile =
        sourcePath != null && sourcePath.isNotEmpty && File(sourcePath).existsSync();

    final canInspect = hasCropFile || (hasSourceFile && item.boundingBox?.isValid == true);

    if (!canInspect) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: sevColor.withValues(alpha: 0.3),
          width: 1.1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showPartCropZoomDialog(
            context,
            item: item,
            report: report,
            lang: lang,
            ttsState: ttsState,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Cropped Thumbnail Preview Box
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 68,
                    height: 68,
                    color: scheme.surfaceContainerHighest,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasCropFile)
                          Image.file(
                            File(item.croppedImagePath!),
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                          )
                        else if (hasSourceFile && item.boundingBox?.isValid == true)
                          _buildFractionalCropFallback(
                            sourcePath,
                            item.boundingBox!,
                          )
                        else
                          Center(
                            child: Icon(
                              _categoryIcon(),
                              size: 32,
                              color: sevColor.withValues(alpha: 0.8),
                            ),
                          ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.fullscreen_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Component Metadata & Auto-Crop Label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: sevColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _categoryIcon(),
                                  size: 11,
                                  color: sevColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  categoryStr,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: sevColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (item.boundingBox != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isKm ? 'កាត់ស្វ័យប្រវត្តិ' : 'Auto Crop',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isKm ? 'រូបភាពកាត់ផ្នែករថយន្ត' : 'Auto-cropped component',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.zoom_in_rounded,
                            size: 13,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isKm
                                ? 'ចុចដើម្បីមើលរូបភាពកាត់ និងទីតាំង'
                                : 'Tap to inspect crop & location',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFractionalCropFallback(String path, BoundingBox box) {
    final centerX = (box.xmin + box.xmax) / 2.0;
    final centerY = (box.ymin + box.ymax) / 2.0;
    final alignX = (centerX * 2.0 - 1.0).clamp(-1.0, 1.0);
    final alignY = (centerY * 2.0 - 1.0).clamp(-1.0, 1.0);

    return FittedBox(
      fit: BoxFit.cover,
      alignment: Alignment(alignX, alignY),
      child: Image.file(File(path), cacheWidth: 600),
    );
  }
}

/// Opens the interactive inspection dialog showing:
/// 1. Centered, high-res cropped component view with pinch-to-zoom.
/// 2. Full vehicle photo with accurately aligned bounding box overlay.
void showPartCropZoomDialog(
  BuildContext context, {
  required DamageItem item,
  required DamageReport report,
  required AppLanguage lang,
  TtsState? ttsState,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _PartCropInspectionDialog(
      item: item,
      report: report,
      lang: lang,
      ttsState: ttsState,
    ),
  );
}

class _PartCropInspectionDialog extends StatefulWidget {
  final DamageItem item;
  final DamageReport report;
  final AppLanguage lang;
  final TtsState? ttsState;

  const _PartCropInspectionDialog({
    required this.item,
    required this.report,
    required this.lang,
    this.ttsState,
  });

  @override
  State<_PartCropInspectionDialog> createState() =>
      _PartCropInspectionDialogState();
}

class _PartCropInspectionDialogState extends State<_PartCropInspectionDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Size? _naturalImageSize;

  String? get _resolvedSourcePath {
    final media = widget.report.allMediaPaths;
    if (media.isNotEmpty && widget.item.imageIndex < media.length) {
      return media[widget.item.imageIndex];
    }
    return media.isNotEmpty ? media.first : null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _resolveSourceImageSize();
  }

  void _resolveSourceImageSize() {
    final path = _resolvedSourcePath;
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;

    final imageProvider = FileImage(file);
    imageProvider.resolve(ImageConfiguration.empty).addListener(
      ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          final size = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
          if (synchronousCall) {
            _naturalImageSize = size;
          } else if (mounted) {
            setState(() {
              _naturalImageSize = size;
            });
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isKm = widget.lang.isKhmer;
    final item = widget.item;
    final sevColor = _severityColor(item.severity);

    final hasCropFile = item.croppedImagePath != null &&
        item.croppedImagePath!.isNotEmpty &&
        File(item.croppedImagePath!).existsSync();

    final sourcePath = _resolvedSourcePath;
    final hasSourceFile =
        sourcePath != null && sourcePath.isNotEmpty && File(sourcePath).existsSync();

    final box = item.boundingBox;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item.isTire
                          ? Icons.tire_repair_rounded
                          : (item.isHydraulic
                              ? Icons.precision_manufacturing_rounded
                              : Icons.car_repair_rounded),
                      color: sevColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKm ? item.resolvedPartNameKhmer : item.partName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${item.componentCategory(isKhmer: isKm)} · ${(item.confidence * 100).toStringAsFixed(0)}% confidence',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Mode Tabs (Cropped Part vs Full Vehicle Overlay)
            TabBar(
              controller: _tabController,
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              indicatorColor: scheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(
                  icon: const Icon(Icons.crop_free_rounded, size: 18),
                  text: isKm ? 'រូបភាពកាត់លម្អិត' : 'Cropped Part',
                ),
                Tab(
                  icon: const Icon(Icons.location_searching_rounded, size: 18),
                  text: isKm ? 'ទីតាំងលើរថយន្ត' : 'Vehicle Context',
                ),
              ],
            ),
            // Tab Contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: High-Res Cropped Component View (Centered & Bordered)
                  Container(
                    color: const Color(0xFF16181D),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 6.0,
                              clipBehavior: Clip.antiAlias,
                              child: Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 24,
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth - 40,
                                    maxHeight: constraints.maxHeight - 64,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: sevColor.withValues(alpha: 0.6),
                                      width: 2.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: hasCropFile
                                      ? Image.file(
                                          File(item.croppedImagePath!),
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                        )
                                      : (hasSourceFile && box != null && box.isValid
                                          ? _buildFractionalCropFallback(
                                              sourcePath,
                                              box,
                                            )
                                          : Center(
                                              child: Text(
                                                isKm
                                                    ? 'មិនមានរូបភាពកាត់'
                                                    : 'No crop available',
                                                style: const TextStyle(
                                                    color: Colors.white70),
                                              ),
                                            )),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.pinch_outlined,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isKm
                                          ? 'ពង្រីក/បង្រួមដោយប្រើម្រាមដៃពីរ'
                                          : 'Pinch to zoom and inspect',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Tab 2: Full Vehicle Image with 100% Accurately Mapped Bounding Box Overlay
                  Container(
                    color: const Color(0xFF16181D),
                    child: hasSourceFile
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              final containerSize = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              final naturalSize = _naturalImageSize ??
                                  Size(containerSize.width, containerSize.height);
                              final fittedSizes = applyBoxFit(
                                BoxFit.contain,
                                naturalSize,
                                containerSize,
                              );
                              final imageRect = Alignment.center.inscribe(
                                fittedSizes.destination,
                                Offset.zero & containerSize,
                              );

                              return InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 5.0,
                                child: Center(
                                  child: SizedBox(
                                    width: containerSize.width,
                                    height: containerSize.height,
                                    child: Stack(
                                      children: [
                                        // The exact vehicle image fitted inside imageRect
                                        Positioned.fromRect(
                                          rect: imageRect,
                                          child: Image.file(
                                            File(sourcePath),
                                            fit: BoxFit.fill,
                                            filterQuality: FilterQuality.medium,
                                          ),
                                        ),
                                        // The bounding box drawn with exact 1:1 pixel alignment over imageRect
                                        if (box != null && box.isValid)
                                          Positioned.fromRect(
                                            rect: imageRect,
                                            child: CustomPaint(
                                              painter: _BoundingBoxPainter(
                                                box: box,
                                                label: isKm
                                                    ? item.resolvedPartNameKhmer
                                                    : item.partName,
                                                severityColor: sevColor,
                                              ),
                                            ),
                                          ),
                                        Positioned(
                                          bottom: 12,
                                          left: 0,
                                          right: 0,
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.75),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.pinch_outlined,
                                                    size: 14,
                                                    color: Colors.white70,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    isKm
                                                        ? 'ពង្រីក/បង្រួមដើម្បីពិនិត្យទីតាំង'
                                                        : 'Pinch to zoom & inspect location',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
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
                                  ),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              isKm ? 'មិនមានរូបភាពដើម' : 'No source image found',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            // Diagnostic Details & Severity Description at Bottom
            Container(
              padding: const EdgeInsets.all(14),
              color: scheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: sevColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.severity.localizedLabel(widget.lang),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: sevColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isKm
                              ? item.resolvedDamageTypeKhmer
                              : item.formattedDamageType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      isKm ? item.resolvedNotesKhmer : item.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFractionalCropFallback(String path, BoundingBox box) {
    final centerX = (box.xmin + box.xmax) / 2.0;
    final centerY = (box.ymin + box.ymax) / 2.0;
    final alignX = (centerX * 2.0 - 1.0).clamp(-1.0, 1.0);
    final alignY = (centerY * 2.0 - 1.0).clamp(-1.0, 1.0);

    return FittedBox(
      fit: BoxFit.cover,
      alignment: Alignment(alignX, alignY),
      child: Image.file(File(path), cacheWidth: 600),
    );
  }
}

/// Custom painter that renders a glowing bounding box, corner brackets, and label
/// with exact pixel coordinates matching the vehicle image.
class _BoundingBoxPainter extends CustomPainter {
  final BoundingBox box;
  final String label;
  final Color severityColor;

  const _BoundingBoxPainter({
    required this.box,
    required this.label,
    required this.severityColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!box.isValid || size.width <= 0 || size.height <= 0) return;

    final left = box.xmin * size.width;
    final top = box.ymin * size.height;
    final width = (box.xmax - box.xmin) * size.width;
    final height = (box.ymax - box.ymin) * size.height;

    final rect = Rect.fromLTWH(left, top, width, height);

    // Semi-transparent fill inside bounding box
    final fillPaint = Paint()
      ..color = severityColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      fillPaint,
    );

    // Border stroke
    final borderPaint = Paint()
      ..color = severityColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      borderPaint,
    );

    // Corner bracket accents
    final cornerLen = (width < height ? width : height) * 0.25;
    final clampedLen = cornerLen.clamp(8.0, 22.0);
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Top-Left corner
    canvas.drawLine(Offset(left, top), Offset(left + clampedLen, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + clampedLen), cornerPaint);

    // Top-Right corner
    canvas.drawLine(Offset(left + width, top), Offset(left + width - clampedLen, top), cornerPaint);
    canvas.drawLine(Offset(left + width, top), Offset(left + width, top + clampedLen), cornerPaint);

    // Bottom-Left corner
    canvas.drawLine(Offset(left, top + height), Offset(left + clampedLen, top + height), cornerPaint);
    canvas.drawLine(Offset(left, top + height), Offset(left, top + height - clampedLen), cornerPaint);

    // Bottom-Right corner
    canvas.drawLine(Offset(left + width, top + height), Offset(left + width - clampedLen, top + height), cornerPaint);
    canvas.drawLine(Offset(left + width, top + height), Offset(left + width, top + height - clampedLen), cornerPaint);

    // Label banner positioned neatly (above the box or inside the top if near screen ceiling)
    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final bannerTop = (top - 22 >= 0) ? (top - 22) : (top + 2);
    final bannerLeft = left.clamp(
      0.0,
      (size.width - (textPainter.width + 12)).clamp(0.0, size.width),
    );

    final bannerRect = Rect.fromLTWH(
      bannerLeft,
      bannerTop.clamp(0.0, (size.height - 18).clamp(0.0, size.height)),
      textPainter.width + 12,
      18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bannerRect, const Radius.circular(4)),
      Paint()..color = severityColor,
    );
    textPainter.paint(
      canvas,
      Offset(bannerRect.left + 6, bannerRect.top + 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.box != box ||
        oldDelegate.label != label ||
        oldDelegate.severityColor != severityColor;
  }
}
