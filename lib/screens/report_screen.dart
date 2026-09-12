import 'dart:io';
import 'package:flutter/material.dart';
import '../models/damage_report.dart';

class ReportScreen extends StatelessWidget {
  final DamageReport report;
  const ReportScreen({super.key, required this.report});

  Color _severityColor(BuildContext context, DamageSeverity s) {
    switch (s) {
      case DamageSeverity.minor:
        return Colors.amber.shade700;
      case DamageSeverity.moderate:
        return Colors.orange.shade800;
      case DamageSeverity.severe:
        return Colors.red.shade700;
      case DamageSeverity.unknown:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Damage Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (File(report.sourceMediaPath).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(report.sourceMediaPath), height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.smart_toy_outlined, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('${report.providerLabel} · ${report.modelUsed}', style: Theme.of(context).textTheme.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (report.summary != null) Text(report.summary!, style: Theme.of(context).textTheme.bodyMedium),
                  if (report.summaryKhmer != null) ...[
                    const SizedBox(height: 6),
                    Text(report.summaryKhmer!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('Overall confidence: ${(report.overallConfidence * 100).toStringAsFixed(0)}%'),
                    ],
                  ),
                  if (report.hasLowConfidenceItems) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Some findings have low confidence — please verify manually.', style: TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Findings (${report.items.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (report.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No damage detected in the submitted media.')),
            )
          else
            ...report.items.map((item) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('${item.partName} (${item.partNameKhmer})',
                                  style: Theme.of(context).textTheme.titleSmall),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _severityColor(context, item.severity).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item.severity.label,
                                style: TextStyle(color: _severityColor(context, item.severity), fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Damage: ${item.damageType.replaceAll('_', ' ')}'),
                        if (item.notes != null && item.notes!.isNotEmpty) Text(item.notes!, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: item.confidence.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  color: item.needsReview ? Colors.orange : Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${(item.confidence * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.bodySmall),
                            if (item.needsReview) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.flag_outlined, size: 14, color: Colors.orange),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
