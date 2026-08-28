import 'package:flutter/material.dart';

import '../../../widgets/segmented_control.dart';

/// Full-width On-device / Cloud toggle for a processing stage.
class StageModeToggle extends StatelessWidget {
  const StageModeToggle({
    super.key,
    required this.isLocal,
    required this.onChanged,
    required this.labels,
  });

  final bool isLocal;
  final ValueChanged<bool> onChanged;
  final ({String local, String cloud}) labels;

  @override
  Widget build(BuildContext context) {
    return AnimatedSegmentedControl(
      options: [
        SegmentOption(labels.local, icon: Icons.shield_outlined),
        SegmentOption(labels.cloud, icon: Icons.cloud_outlined),
      ],
      selectedIndex: isLocal ? 0 : 1,
      onChanged: (i) => onChanged(i == 0),
    );
  }
}
