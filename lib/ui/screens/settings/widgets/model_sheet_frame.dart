import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';

/// Matches the share overlay's surface, corner radius and subtle drag handle.
class ModelSheetFrame extends StatelessWidget {
  const ModelSheetFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .92,
    ),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusSheet),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.palette.line2,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}
