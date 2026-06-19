import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../data/models/transcript_note.dart';
import '../../../services/processing/processing_pipeline.dart';
import '../../../services/processing/processing_profile.dart';
import '../../../services/service_exceptions.dart';
import '../../../state/processing_controller.dart';
import '../../../state/settings_controller.dart';
import '../../navigation.dart';
import '../../widgets/buttons.dart';
import '../../widgets/effects.dart';
import '../../widgets/surfaces.dart';
import '../../widgets/waveforms.dart';
import '../detail/widgets/detail_audio_player.dart';

/// Presents the share overlay as an in-app modal bottom sheet when audio is
/// shared into or opened with the app.
abstract final class ShareOverlay {
  static Future<void> show({required String audioPath, String? fileName}) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final isTablet = MediaQuery.of(ctx).size.width >= 720;
    await showModalBottomSheet<void>(
      context: ctx,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      constraints: isTablet ? const BoxConstraints(maxWidth: 600) : null,
      builder: (sheetCtx) => ShareSheetContent(
        audioPath: audioPath,
        fileName: fileName,
        onFinished: () => Navigator.of(sheetCtx).pop(),
      ),
    );
  }
}

/// The share sheet body: runs the pipeline and shows a live processing state,
/// then a result preview (audio + summary + key points) that the user explicitly
/// saves. The preview is NOT persisted automatically — only "Speichern" commits
/// it, so a shared note never silently lands in the history.
///
/// [onFinished] is invoked when the sheet should close (saved or discarded).
class ShareSheetContent extends ConsumerStatefulWidget {
  const ShareSheetContent({
    super.key,
    required this.audioPath,
    required this.onFinished,
    this.fileName,
  });

  final String audioPath;
  final String? fileName;
  final VoidCallback onFinished;

  @override
  ConsumerState<ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends ConsumerState<ShareSheetContent> {
  late final ProcessingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(processingControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    _controller
      ..reset()
      ..run(
        audioPath: widget.audioPath,
        source: NoteSource.shared,
        fileName: widget.fileName,
        save: false,
      );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _controller.commit();
    widget.onFinished();
  }

  void _openSettings() {
    widget.onFinished();
    final ctx = navigatorKey.currentContext;
    if (ctx != null) AppNavigator.openSettings(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final media = MediaQuery.of(context);
    final state = ref.watch(processingControllerProvider);

    final Widget body;
    final bool fill; // result view fills the sheet; processing/error are compact
    if (state.hasError) {
      body = _ErrorBody(
        error: state.error!,
        isModelMissing: state.error is ModelNotDownloadedException,
        onRetry: _start,
        onClose: widget.onFinished,
        onOpenSettings: _openSettings,
      );
      fill = false;
    } else if (state.result != null) {
      body = _ResultBody(
        note: state.result!,
        saving: _saving,
        onClose: widget.onFinished,
        onSave: _save,
      );
      fill = true;
    } else {
      body = const _ProcessingBody();
      fill = false;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
              children: [
                const _DragHandle(),
                if (fill) Expanded(child: body) else Flexible(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.palette.line2,
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
    );
  }
}

// ── Processing state ────────────────────────────────────────────────────────

class _ProcessingBody extends ConsumerWidget {
  const _ProcessingBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final state = ref.watch(processingControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final profile = ProcessingProfile.resolve(settings);
    final transcribing = state.step == ProcessingStep.transcribing;
    final stage = transcribing ? profile.asr : profile.summary;

    final statusText = state.modelProgress != null
        ? '${t.downloading} ${(state.modelProgress! * 100).round()}%'
        : (stage.isLocal ? '${t.runningLocal} · ${stage.name}' : '${stage.name} · ${stage.sub}');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(34, 18, 34, 28),
      child: Column(
        children: [
          const PulseRingHero(),
          const SizedBox(height: 18),
          Text(
            transcribing ? t.shTranscribe : t.shSummarize,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: palette.ink),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: stage.isLocal ? palette.mint : palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 13, color: palette.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (settings.summarizeEnabled) ...[
            const SizedBox(height: 28),
            StepIndicator(
              step1Label: t.shStep1,
              step2Label: t.shStep2,
              activeStepIsSecond: !transcribing,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Result preview ──────────────────────────────────────────────────────────

class _ResultBody extends ConsumerStatefulWidget {
  const _ResultBody({
    required this.note,
    required this.saving,
    required this.onClose,
    required this.onSave,
  });

  final TranscriptNote note;
  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  ConsumerState<_ResultBody> createState() => _ResultBodyState();
}

class _ResultBodyState extends ConsumerState<_ResultBody> {
  bool _transcriptOpen = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final note = widget.note;
    final hasSummary = note.gist.isNotEmpty;

    return Column(
      children: [
        _ResultHeader(title: note.title, label: t.shFrom, onClose: widget.onClose),
        Expanded(
          child: FadeEdges(
            topHeight: 10,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              children: [
                if (note.audioPath != null)
                  DetailAudioPlayer(audioPath: note.audioPath!, durationSec: note.durationSec),
                const SizedBox(height: 16),
                if (hasSummary) ...[
                  _SummaryCard(gist: note.gist, label: t.shSummary),
                  const SizedBox(height: 16),
                ],
                _MetaChips(note: note, strings: t),
                if (note.points.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _SectionLabel(t.shPoints),
                  const SizedBox(height: 12),
                  _KeyPoints(points: note.points),
                ],
                if (note.todos.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _TodosPreview(todos: note.todos, label: t.shActions),
                ],
                const SizedBox(height: 22),
                // Summary-only notes hide the transcript behind a toggle; raw
                // transcripts show it directly.
                if (hasSummary)
                  PillButton(
                    label: _transcriptOpen ? t.shHide : t.shShow,
                    icon: Icons.subject_rounded,
                    trailingIcon: _transcriptOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    height: 50,
                    outlined: true,
                    onTap: () => setState(() => _transcriptOpen = !_transcriptOpen),
                  ),
                if (!hasSummary || _transcriptOpen) ...[
                  const SizedBox(height: 14),
                  _TranscriptPreview(note: note, label: t.shTranscript),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: PillButton(
            label: t.shSave,
            icon: Icons.check_rounded,
            onTap: widget.saving ? () {} : widget.onSave,
          ),
        ),
      ],
    );
  }
}

/// Read-only to-do list shown in the share preview (editable after saving).
class _TodosPreview extends StatelessWidget {
  const _TodosPreview({required this.todos, required this.label});
  final List<TodoItem> todos;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionLabel(label),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(color: palette.coral, borderRadius: BorderRadius.circular(9999)),
              child: Center(
                child: Text('${todos.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final todo in todos)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 18, color: palette.coral),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(todo.text,
                      style: TextStyle(fontSize: 14.5, height: 1.45, color: palette.body),),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The time-stamped transcript shown inside the share preview.
class _TranscriptPreview extends StatelessWidget {
  const _TranscriptPreview({required this.note, required this.label});
  final TranscriptNote note;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        const SizedBox(height: 12),
        for (final line in note.transcript)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Text(line.time, style: AppTheme.mono(color: palette.accent, size: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(line.text, style: TextStyle(fontSize: 14.5, height: 1.5, color: palette.body)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.title, required this.label, required this.onClose});

  final String title;
  final String label;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: MiniWave()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: palette.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconCircleButton(icon: Icons.close_rounded, size: 38, onTap: onClose),
        ],
      ),
    );
  }
}

// ── Error state ─────────────────────────────────────────────────────────────

class _ErrorBody extends ConsumerWidget {
  const _ErrorBody({
    required this.error,
    required this.isModelMissing,
    required this.onRetry,
    required this.onClose,
    required this.onOpenSettings,
  });

  final Object error;
  final bool isModelMissing;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.coralSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.error_outline_rounded, color: palette.coralInk, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            isModelMissing ? t.modelMissingTitle : t.errorTitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: palette.ink),
          ),
          const SizedBox(height: 8),
          Text(
            isModelMissing ? t.modelMissingBody : error.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: palette.muted),
          ),
          const SizedBox(height: 22),
          PillButton(
            label: isModelMissing ? t.goToSettings : t.retry,
            height: 52,
            onTap: isModelMissing ? onOpenSettings : onRetry,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onClose,
            child: Text(t.dismiss, style: TextStyle(color: palette.muted, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Shared result sub-widgets (mirror the detail screen) ─────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.gist, required this.label});
  final String gist;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accentSoft2, palette.accentSoft],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 17, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: palette.accentDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            gist,
            style: TextStyle(fontSize: 15.5, height: 1.5, fontWeight: FontWeight.w500, color: palette.body),
          ),
        ],
      ),
    );
  }
}

class _MetaChips extends StatelessWidget {
  const _MetaChips({required this.note, required this.strings});
  final TranscriptNote note;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(icon: Icons.schedule_rounded, label: formatDuration(note.durationSec)),
        _Chip(icon: Icons.person_outline_rounded, label: strings.mSpkTemplate.replaceAll('{n}', '1')),
        _Chip(icon: Icons.language_rounded, label: strings.autoLang),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: palette.chip, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.muted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.body)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: context.palette.ink,
        ),
      ),
    );
  }
}

class _KeyPoints extends StatelessWidget {
  const _KeyPoints({required this.points});
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(point, style: TextStyle(fontSize: 14.5, height: 1.45, color: palette.body)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
