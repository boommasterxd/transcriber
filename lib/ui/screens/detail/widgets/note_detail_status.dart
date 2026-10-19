import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';

class NoteDetailStatus extends StatelessWidget {
  const NoteDetailStatus({
    super.key,
    required this.loading,
    required this.strings,
    required this.retry,
  });

  final bool loading;
  final AppStrings strings;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: loading
        ? const CircularProgressIndicator()
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.errorTitle),
              TextButton(onPressed: retry, child: Text(strings.retry)),
            ],
          ),
  );
}
