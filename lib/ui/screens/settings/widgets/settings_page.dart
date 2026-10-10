import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../widgets/surfaces.dart';

/// Shared scrollable settings layout with a wrapping title and back action.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.bg,
    body: SafeArea(
      bottom: footer != null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: Row(
              children: [
                BackButton(color: context.palette.body),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: context.palette.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FadeEdges(
              builder: (context, controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 36),
                children: children,
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: footer,
            ),
        ],
      ),
    ),
  );
}
