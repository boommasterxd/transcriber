import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/note_history.dart';
import '../../../../state/history_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../navigation.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/surfaces.dart';
import '../history_logic.dart';
import 'active_model_pill.dart';
import 'home_actions.dart';
import 'home_search_bar.dart';
import 'phone_history.dart';
import 'history_page_controls.dart';

class PhoneHomeView extends ConsumerWidget {
  const PhoneHomeView({
    super.key,
    required this.onQueryChanged,
    required this.onPickFile,
  });

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(historyControllerProvider);
    final strings = ref.watch(stringsProvider);
    final data = _HomeData(
      page: page,
      query: ref.read(historyControllerProvider.notifier).query,
      strings: strings,
      modelStatus: ref.watch(homeModelStatusProvider),
      groups: groupNotesByAge(
        page.asData?.value.entries ?? const [],
        now: DateTime.now(),
      ),
    );

    return Scaffold(
      backgroundColor: context.palette.bg,
      body: Stack(
        children: [
          _HomeList(
            data: data,
            onQueryChanged: onQueryChanged,
            onPickFile: onPickFile,
          ),
          _RecordButtonPosition(strings: strings),
        ],
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.page,
    required this.query,
    required this.strings,
    required this.modelStatus,
    required this.groups,
  });

  final AsyncValue<HistoryPage> page;
  final String query;
  int get noteCount => page.asData?.value.totalCount ?? 0;
  final AppStrings strings;
  final HomeModelStatus modelStatus;
  final List<HistoryGroup> groups;
}

class _HomeList extends StatelessWidget {
  const _HomeList({
    required this.data,
    required this.onQueryChanged,
    required this.onPickFile,
  });

  final _HomeData data;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return FadeEdges(
      topHeight: 54,
      bottomHeight: 92,
      builder: (context, controller) => CustomScrollView(
        controller: controller,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: 56),
            sliver: SliverToBoxAdapter(
              child: _HomeControls(
                data: data,
                onQueryChanged: onQueryChanged,
                onPickFile: onPickFile,
              ),
            ),
          ),
          if (data.groups.isEmpty &&
              !data.page.isLoading &&
              !data.page.hasError)
            SliverToBoxAdapter(
              child: HomeEmptyState(
                title: data.strings.emptyTitle,
                subtitle: data.strings.emptySub,
              ),
            )
          else
            PhoneHistory(groups: data.groups, strings: data.strings),
          SliverToBoxAdapter(
            child: HistoryPageControls(page: data.page, strings: data.strings),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 104)),
        ],
      ),
    );
  }
}

class _HomeControls extends StatelessWidget {
  const _HomeControls({
    required this.data,
    required this.onQueryChanged,
    required this.onPickFile,
  });

  final _HomeData data;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    final strings = data.strings;
    return Column(
      children: [
        _HomeHeader(noteCount: data.noteCount, strings: strings),
        const SizedBox(height: 18),
        _HorizontalPadding(
          child: HomeSearchBar(
            hint: strings.search,
            onChanged: onQueryChanged,
            query: data.query,
          ),
        ),
        const SizedBox(height: 12),
        _HorizontalPadding(
          child: ActiveModelPill(
            label: data.modelStatus.label,
            activeText: strings.modelActive,
            warning: data.modelStatus.warning,
            onTap: () => AppNavigator.openSettings(context),
          ),
        ),
        const SizedBox(height: 18),
        _HorizontalPadding(
          child: AudioFileTile(
            title: strings.pickTitle,
            subtitle: strings.pickSub,
            onTap: onPickFile,
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.noteCount, required this.strings});

  final int noteCount;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.homeTitle,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.homeSub(noteCount),
                  style: TextStyle(fontSize: 13.5, color: palette.muted),
                ),
              ],
            ),
          ),
          IconCircleButton(
            icon: Icons.settings_outlined,
            size: 44,
            onTap: () => AppNavigator.openSettings(context),
          ),
        ],
      ),
    );
  }
}

class _HorizontalPadding extends StatelessWidget {
  const _HorizontalPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: child,
  );
}

class _RecordButtonPosition extends StatelessWidget {
  const _RecordButtonPosition({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Positioned(
    bottom: 26,
    left: 0,
    right: 0,
    child: Center(
      child: RecordFab(
        semanticLabel: strings.tabRecord,
        onTap: () => AppNavigator.openRecord(context),
      ),
    ),
  );
}
