import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../services/remote/remote_api_client.dart';
import '../../../widgets/keyboard_action_target.dart';

/// Activates a model choice independently of keyboard focus traversal.
class RemoteModelOption extends StatelessWidget {
  const RemoteModelOption({
    super.key,
    required this.model,
    required this.selected,
    required this.onActivate,
  });

  final RemoteModelInfo model;
  final bool selected;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasSeparateId = model.display != model.id;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: KeyboardActionTarget(
        action: (
          label: hasSeparateId
              ? '${model.display}\n${model.id}'
              : model.display,
          onActivate: onActivate,
          focusBorderRadius: BorderRadius.circular(12),
          selected: selected,
          inMutuallyExclusiveGroup: true,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          child: Row(
            children: [
              _SelectionMark(selected: selected),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.display,
                      style: TextStyle(fontSize: 15, color: palette.ink),
                    ),
                    if (hasSeparateId) ...[
                      const SizedBox(height: 4),
                      Text(
                        model.id,
                        style: TextStyle(fontSize: 12.5, color: palette.body),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? palette.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: selected
            ? null
            : Border.all(color: palette.accentDeep, width: 2),
      ),
      child: selected
          ? Icon(Icons.check, color: palette.onAccent, size: 13)
          : null,
    );
  }
}
