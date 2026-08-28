import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/state/model_manager_controller.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/settings/widgets/downloadable_model_tile.dart';
import 'package:transcriber/ui/screens/settings/widgets/local_stage_model_list.dart';
import 'package:transcriber/ui/widgets/model_tile.dart';

import '../../../support/widget_test_utils.dart';

void main() {
  _registerModelStatusTests();
  _registerErrorTests();
  _registerListTests();
}

void _registerModelStatusTests() {
  testWidgets('not downloaded model starts download from row and chip', (
    tester,
  ) async {
    var downloads = 0;
    await tester.pumpWidget(
      _app(
        _tile(status: const ModelStatus(), download: () async => downloads++),
      ),
    );

    expect(find.text('Get'), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);

    await tester.tap(find.text('Test model'));
    await tester.pump();
    await tester.tap(find.text('Get'));
    await tester.pump();
    expect(downloads, 2);
  });

  testWidgets('downloading model shows progress and ignores row taps', (
    tester,
  ) async {
    var actions = 0;
    await tester.pumpWidget(
      _app(
        _tile(
          status: const ModelStatus(
            status: DownloadStatus.downloading,
            progress: 0.42,
          ),
          download: () async => actions++,
        ),
      ),
    );

    expect(find.byType(ProgressRing), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Get'), findsNothing);
    await tester.tap(find.text('Test model'));
    await tester.pump();
    expect(actions, 0);
  });

  testWidgets('downloaded model selects and confirms deletion', (tester) async {
    var selected = 0;
    var deleted = 0;
    final strings = AppStrings.of(AppLanguage.en);
    await tester.pumpWidget(
      _app(
        _tile(
          status: const ModelStatus(status: DownloadStatus.downloaded),
          selected: true,
          select: () => selected++,
          delete: () async => deleted++,
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    await tester.tap(find.text('Test model'));
    expect(selected, 1);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpUntilSettled();
    expect(find.text(strings.deleteModelConfirm), findsOneWidget);
    await tester.tap(find.text(strings.cancel));
    await tester.pumpUntilSettled();
    expect(deleted, 0);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpUntilSettled();
    await tester.tap(find.text(strings.delete));
    await tester.pump();
    expect(deleted, 1);
  });
}

void _registerErrorTests() {
  testWidgets('download failure is presented as a snackbar', (tester) async {
    await tester.pumpWidget(
      _app(
        _tile(
          status: const ModelStatus(),
          download: () async => throw StateError('download failed'),
        ),
      ),
    );

    await tester.tap(find.text('Get'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('download failed'), findsOneWidget);
  });

  testWidgets('delete failure is presented as a snackbar', (tester) async {
    final strings = AppStrings.of(AppLanguage.en);
    await tester.pumpWidget(
      _app(
        _tile(
          status: const ModelStatus(status: DownloadStatus.downloaded),
          delete: () async => throw StateError('delete failed'),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpUntilSettled();
    await tester.tap(find.text(strings.delete));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('delete failed'), findsOneWidget);
  });
}

void _registerListTests() {
  testWidgets('local model list forwards option ids to actions', (
    tester,
  ) async {
    final selected = <String>[];
    final downloaded = <String>[];
    final deleted = <String>[];
    await tester.pumpWidget(
      _app(
        LocalStageModelList(
          icon: Icons.mic,
          downloadLabel: 'Get',
          options: [
            (
              id: 'first',
              title: 'First model',
              subtitle: '10 MB',
              status: const ModelStatus(),
              selected: false,
            ),
            (
              id: 'second',
              title: 'Second model',
              subtitle: '20 MB',
              status: const ModelStatus(status: DownloadStatus.downloaded),
              selected: false,
            ),
          ],
          actions: LocalStageModelActions(
            select: selected.add,
            download: (id) async => downloaded.add(id),
            delete: (id) async => deleted.add(id),
          ),
        ),
      ),
    );

    expect(find.text('First model'), findsOneWidget);
    expect(find.text('Second model'), findsOneWidget);
    await tester.tap(find.text('First model'));
    await tester.pump();
    await tester.tap(find.text('Second model'));
    expect(downloaded, ['first']);
    expect(selected, ['second']);
    expect(deleted, isEmpty);
  });
}

Widget _app(Widget child) => ProviderScope(
  overrides: [stringsProvider.overrideWithValue(AppStrings.of(AppLanguage.en))],
  child: MaterialApp(
    theme: ThemeData(
      extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.blue)],
    ),
    home: Scaffold(body: child),
  ),
);

DownloadableModelTile _tile({
  required ModelStatus status,
  bool selected = false,
  VoidCallback? select,
  Future<void> Function()? download,
  Future<void> Function()? delete,
}) => DownloadableModelTile(
  copy: (
    icon: Icons.mic,
    title: 'Test model',
    subtitle: '10 MB',
    downloadLabel: 'Get',
  ),
  selection: (status: status, selected: selected, isLast: true),
  actions: (
    select: select ?? () {},
    download: download ?? () async {},
    delete: delete,
  ),
);
