import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inspection_scope.dart';
import '../providers/app_state.dart';

/// Shows the unified Inspection Scope, Audio Analysis, & Incident Notes modal bottom sheet.
Future<void> showInspectionScopeModal(
  BuildContext context,
  WidgetRef ref, {
  bool? analyzeWithAudio,
  ValueChanged<bool>? onAudioChanged,
  TextEditingController? contextController,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _InspectionScopeModalSheet(
      analyzeWithAudio: analyzeWithAudio,
      onAudioChanged: onAudioChanged,
      contextController: contextController,
    ),
  );
}

class _InspectionScopeModalSheet extends ConsumerStatefulWidget {
  final bool? analyzeWithAudio;
  final ValueChanged<bool>? onAudioChanged;
  final TextEditingController? contextController;

  const _InspectionScopeModalSheet({
    this.analyzeWithAudio,
    this.onAudioChanged,
    this.contextController,
  });

  @override
  ConsumerState<_InspectionScopeModalSheet> createState() =>
      _InspectionScopeModalSheetState();
}

class _InspectionScopeModalSheetState
    extends ConsumerState<_InspectionScopeModalSheet> {
  late bool _localAudio = widget.analyzeWithAudio ?? true;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final scope = ref.watch(inspectionScopeProvider);
    final scheme = Theme.of(context).colorScheme;
    final allTagsSelected =
        scope.activeDefectTags.length == InspectionScope.allDefectTags.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header: Title, subtitle, and Reset button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.inspectionTargetTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.inspectionTargetSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!scope.isDefault)
                    TextButton(
                      key: const Key('reset_inspection_scope_button'),
                      onPressed: () =>
                          ref.read(inspectionScopeProvider.notifier).reset(),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(
                        strings.resetBtn,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body Content: Audio, Zone, Defect Tags, Context Notes
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  // SECTION 1: ANALYZE WITH VEHICLE AUDIO
                  if (widget.onAudioChanged != null) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: _localAudio
                            ? scheme.primaryContainer.withValues(alpha: 0.28)
                            : scheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _localAudio
                              ? scheme.primary.withValues(alpha: 0.45)
                              : scheme.outlineVariant,
                          width: 1.2,
                        ),
                      ),
                      child: CheckboxListTile(
                        key: const Key('analyze_with_audio_checkbox'),
                        value: _localAudio,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onChanged: (val) {
                          final newVal = val ?? true;
                          setState(() => _localAudio = newVal);
                          widget.onAudioChanged?.call(newVal);
                        },
                        title: Row(
                          children: [
                            Icon(
                              Icons.graphic_eq_rounded,
                              size: 20,
                              color: _localAudio
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                strings.analyzeWithAudioLabel,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            strings.analyzeWithAudioSubtitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // SECTION 2: DIAGNOSTIC CONTEXT / INCIDENT NOTES
                  if (widget.contextController != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
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
                                child: Icon(Icons.edit_note_outlined,
                                    size: 18, color: scheme.primary),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      strings.contextNotesTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      strings.contextNotesSubtitle,
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
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: widget.contextController!,
                            builder: (context, value, _) {
                              return TextField(
                                controller: widget.contextController,
                                maxLines: 2,
                                minLines: 1,
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(fontSize: 13.5),
                                decoration: InputDecoration(
                                  hintText: strings.contextNotesHint,
                                  hintStyle: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                                  suffixIcon: value.text.isNotEmpty
                                      ? IconButton(
                                          tooltip: 'Clear notes',
                                          icon: const Icon(Icons.close,
                                              size: 18),
                                          onPressed: () =>
                                              widget.contextController!.clear(),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // SECTION 3: VEHICLE ZONE
                  Text(
                    strings.vehicleZoneHeader,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: InspectionScope.inspectionAreas.map((area) {
                      final isSelected = scope.selectedArea == area.label;
                      return ChoiceChip(
                        avatar: isSelected
                            ? null
                            : Icon(
                                area.icon,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                        label: Text(
                          strings.translateArea(area.label),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          ref
                              .read(inspectionScopeProvider.notifier)
                              .setArea(area.label);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                  // SECTION 3: DEFECT FOCUS TAGS
                  Row(
                    children: [
                      Text(
                        strings.defectFocusHeader,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${scope.activeDefectTags.length}/${InspectionScope.allDefectTags.length}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        key: const Key('toggle_all_defect_tags_button'),
                        onPressed: () {
                          if (allTagsSelected) {
                            ref
                                .read(inspectionScopeProvider.notifier)
                                .clearAllTags();
                          } else {
                            ref
                                .read(inspectionScopeProvider.notifier)
                                .selectAllTags();
                          }
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          allTagsSelected
                              ? strings.clearAllTagsBtn
                              : strings.selectAllTagsBtn,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: InspectionScope.allDefectTags.map((tag) {
                      final isSelected = scope.activeDefectTags.contains(tag);
                      return FilterChip(
                        label: Text(
                          strings.translateDefectTag(tag),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          ref
                              .read(inspectionScopeProvider.notifier)
                              .toggleDefectTag(tag);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Bottom Action Bar: Done button
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('apply_inspection_scope_button'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      strings.doneBtn,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
