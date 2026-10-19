import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
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
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      for (final group in groups) ...[
        SliverToBoxAdapter(
          child: SectionLabel(
            historyPeriodLabel(group.period, strings),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          sliver: SliverList.builder(
            itemCount: group.notes.length,
            itemBuilder: (context, index) => Material(
              key: ValueKey(group.notes[index].id),
              color: context.palette.surface,
              borderRadius: BorderRadius.vertical(
                top: index == 0 ? const Radius.circular(22) : Radius.zero,
                bottom: index == group.notes.length - 1
                    ? const Radius.circular(22)
                    : Radius.zero,
              ),
              clipBehavior: Clip.antiAlias,
              child: DismissibleHistoryNote(
                note: group.notes[index],
                strings: strings,
                child: NoteListItem(
                  note: group.notes[index],
                  strings: strings,
                  isLast: index == group.notes.length - 1,
                  onTap: () =>
                      AppNavigator.openDetail(context, group.notes[index].id),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}
