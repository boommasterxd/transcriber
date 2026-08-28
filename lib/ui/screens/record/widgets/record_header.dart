import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../widgets/buttons.dart';

/// Header for the in-app recording screen.
class RecordHeader extends StatelessWidget {
  const RecordHeader({super.key, required this.title, required this.onCancel});

  final String title;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: Row(
        children: [
          IconCircleButton(icon: Icons.close_rounded, onTap: onCancel),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.palette.ink,
              ),
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }
}
