import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/color_utils.dart';
import '../../../widgets/surfaces.dart';

/// Accessible destination row used by the settings overview and subpages.
class SettingsNavigationTile extends StatelessWidget {
  const SettingsNavigationTile({
    super.key,
    required this.title,
    required this.icon,
    required this.page,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final Widget page;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    clip: true,
    child: Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _NavigationIcon(icon: icon),
        title: Text(
          title,
          style: TextStyle(
            color: context.palette.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: TextStyle(color: context.palette.muted)),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: context.palette.muted,
        ),
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => page));
        },
      ),
    ),
  );
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (foreground, background) = switch (icon) {
      Icons.keyboard_outlined => (palette.accent, palette.accentSoft),
      Icons.tune_rounded => (palette.mint, palette.mintSoft),
      Icons.settings_outlined => (palette.coralInk, palette.coralSoft),
      _ => (palette.accent, null),
    };
    if (background == null) return Icon(icon, color: foreground);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: mixSrgb(foreground, palette.ink, palette.isDark ? 0.8 : 0.7),
        size: 22,
      ),
    );
  }
}
