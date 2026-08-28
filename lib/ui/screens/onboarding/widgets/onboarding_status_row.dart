import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

class OnboardingStatusRow extends StatelessWidget {
  const OnboardingStatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: palette.accentSoft2,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: palette.accent),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        trailing,
      ],
    );
  }
}
