import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/color_utils.dart';
import '../../../../state/settings_controller.dart';

/// Plain-background instructions for dictating into another app's text field.
class KeyboardGuide extends ConsumerWidget {
  const KeyboardGuide({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final steps = [
      strings.keyboardGuideEnable,
      strings.keyboardGuideDictate,
      strings.keyboardGuideFinish,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            strings.keyboardGuideTitle,
            style: TextStyle(
              color: _guideTextColor(context),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.keyboardGuideBenefit,
          style: TextStyle(color: _guideTextColor(context), height: 1.45),
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < steps.length; index++)
          _GuideStep(number: index + 1, text: steps[index]),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$number.',
              style: TextStyle(
                color: _guideTextColor(context),
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _guideTextColor(context), height: 1.45),
            ),
          ),
        ],
      ),
    ),
  );
}

Color _guideTextColor(BuildContext context) =>
    mixSrgb(context.palette.muted, context.palette.body, 0.7);
