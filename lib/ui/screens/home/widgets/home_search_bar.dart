import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Rounded search field that filters the transcript history.
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: palette.faint),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(fontSize: 15, color: palette.ink),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(fontSize: 15, color: palette.faint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
