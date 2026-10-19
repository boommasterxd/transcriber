import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../data/models/note_history.dart';
import '../../../../state/history_controller.dart';

class HistoryPageControls extends ConsumerWidget {
  const HistoryPageControls({
    super.key,
    required this.page,
    required this.strings,
  });

  final AsyncValue<HistoryPage> page;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = page.asData?.value;
    final controller = ref.read(historyControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (page.isLoading) const LinearProgressIndicator(),
          if (page.hasError)
            TextButton.icon(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh),
              label: Text(strings.retry),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: strings.previousPage,
                onPressed: !page.isLoading && (data?.hasPrevious ?? false)
                    ? controller.previous
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: strings.nextPage,
                onPressed: !page.isLoading && (data?.hasNext ?? false)
                    ? controller.next
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
