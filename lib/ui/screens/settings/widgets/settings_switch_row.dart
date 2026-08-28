import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Shared switch row used by settings that enable a single user-facing feature.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.content,
    required this.value,
    required this.onChanged,
  });

  final ({IconData data, Color foreground, Color background}) icon;
  final ({String title, String subtitle, double? subtitleHeight}) content;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        _SettingsSwitchIcon(icon: icon),
        const SizedBox(width: 13),
        Expanded(child: _SettingsSwitchCopy(content: content)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: palette.accent,
          inactiveTrackColor: palette.line2,
        ),
      ],
    );
  }
}

class _SettingsSwitchIcon extends StatelessWidget {
  const _SettingsSwitchIcon({required this.icon});

  final ({IconData data, Color foreground, Color background}) icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: icon.background,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon.data, size: 18, color: icon.foreground),
  );
}

class _SettingsSwitchCopy extends StatelessWidget {
  const _SettingsSwitchCopy({required this.content});

  final ({String title, String subtitle, double? subtitleHeight}) content;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        Text(
          content.subtitle,
          style: TextStyle(
            fontSize: 12.5,
            height: content.subtitleHeight,
            color: palette.muted,
          ),
        ),
      ],
    );
  }
}
