import 'package:flutter/material.dart';

import '../../../widgets/segmented_control.dart';

/// Full-width On-device / Cloud toggle for a processing stage.
class StageModeToggle extends StatelessWidget {
  const StageModeToggle({
    super.key,
    required this.isLocal,
    required this.onChanged,
    required this.localLabel,
    required this.cloudLabel,
  });

  final bool isLocal;
  final ValueChanged<bool> onChanged;
  final String localLabel;
  final String cloudLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedSegmentedControl(
      options: [
        SegmentOption(localLabel, icon: Icons.shield_outlined),
        SegmentOption(cloudLabel, icon: Icons.cloud_outlined),
      ],
      selectedIndex: isLocal ? 0 : 1,
      onChanged: (i) => onChanged(i == 0),
    );
  }
}
