import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../widgets/surfaces.dart';
import '../../../navigation.dart';
import '../history_logic.dart';
import '../note_presentation.dart';
import 'note_list_item.dart';
import 'swipe_delete_background.dart';

class PhoneHistory extends StatelessWidget {
  const PhoneHistory({super.key, required this.groups, required this.strings});

  final List<HistoryGroup> groups;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final group in groups)
          _HistorySection(group: group, strings: strings),
      ],
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.group, required this.strings});

  final HistoryGroup group;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionLabel(
          historyPeriodLabel(group.period, strings),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: SurfaceCard(
            clip: true,
            child: Column(
              children: [
                for (var index = 0; index < group.notes.length; index++)
                  DismissibleHistoryNote(
                    note: group.notes[index],
                    strings: strings,
                    child: NoteListItem(
                      note: group.notes[index],
                      strings: strings,
                      isLast: index == group.notes.length - 1,
                      onTap: () => AppNavigator.openDetail(
                        context,
                        group.notes[index].id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
