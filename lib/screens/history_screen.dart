import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import 'report_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyProvider);
    final dateFormat = DateFormat('MMM d, y · h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(historyProvider.notifier).refresh(),
          ),
        ],
      ),
      body: historyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(child: Text('No past reports yet. Run an analysis to see it here.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = reports[i];
              final thumb = File(r.sourceMediaPath);
              return Card(
                child: ListTile(
                  leading: thumb.existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(thumb, width: 48, height: 48, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.image_not_supported_outlined),
                  title: Text('${r.items.length} finding(s) · ${r.providerLabel}'),
                  subtitle: Text(dateFormat.format(r.createdAt)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref.read(historyProvider.notifier).remove(r.id),
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportScreen(report: r))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
