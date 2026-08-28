import 'dart:async';
import 'dart:convert';

import '../../data/models/transcript_note.dart';
import '../service_exceptions.dart';
import 'processing_request.dart';

sealed class ProcessingForegroundEvent {
  const ProcessingForegroundEvent();
}

final class ProcessingForegroundStepEvent extends ProcessingForegroundEvent {
  const ProcessingForegroundStepEvent(this.step);

  final ProcessingStep step;
}

final class ProcessingForegroundProgressEvent
    extends ProcessingForegroundEvent {
  const ProcessingForegroundProgressEvent(this.progress);

  final double progress;
}

final class ProcessingForegroundDoneEvent extends ProcessingForegroundEvent {
  const ProcessingForegroundDoneEvent(this.note);

  final TranscriptNote note;
}

final class ProcessingForegroundErrorEvent extends ProcessingForegroundEvent {
  const ProcessingForegroundErrorEvent(this.error);

  final ProcessingException error;
}

/// Decodes untrusted foreground-isolate messages without throwing.
ProcessingForegroundEvent? decodeProcessingForegroundEvent(Object? data) {
  try {
    if (data is! Map) return null;
    return switch (data['type']) {
      'step' => _decodeStep(data['step']),
      'modelProgress' => _decodeProgress(data['value']),
      'done' => _decodeDone(data['note']),
      'error' => _decodeError(data['error']),
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

ProcessingForegroundEvent? _decodeStep(Object? value) {
  if (value is! String) return null;
  for (final step in ProcessingStep.values) {
    if (step.name == value) return ProcessingForegroundStepEvent(step);
  }
  return null;
}

ProcessingForegroundEvent? _decodeProgress(Object? value) {
  if (value is! num) return null;
  final progress = value.toDouble();
  if (!progress.isFinite || progress < 0 || progress > 1) return null;
  return ProcessingForegroundProgressEvent(progress);
}

ProcessingForegroundEvent _decodeDone(Object? value) {
  try {
    if (value is! String) throw const FormatException();
    final decoded = jsonDecode(value);
    if (decoded is! Map) throw const FormatException();
    final json = decoded.cast<String, dynamic>();
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) throw const FormatException();
    return ProcessingForegroundDoneEvent(TranscriptNote.fromJson(json));
  } catch (_) {
    return const ProcessingForegroundErrorEvent(
      ProcessingException('Invalid processing result received'),
    );
  }
}

ProcessingForegroundEvent _decodeError(Object? value) {
  final message = value is String ? value.trim() : '';
  return ProcessingForegroundErrorEvent(
    ProcessingException(message.isEmpty ? 'Processing failed' : message),
  );
}

/// Applies decoded events once and completes on the first terminal event.
final class ProcessingForegroundSession {
  ProcessingForegroundSession({
    this.callbacks = const ProcessingCallbacks(),
    this.onSummaryStep,
  });

  final ProcessingCallbacks callbacks;
  final void Function()? onSummaryStep;
  final Completer<TranscriptNote> _completer = Completer<TranscriptNote>();

  Future<TranscriptNote> get result => _completer.future;

  void onData(Object? data) {
    if (_completer.isCompleted) return;
    final event = decodeProcessingForegroundEvent(data);
    switch (event) {
      case ProcessingForegroundStepEvent():
        _handleStep(event.step);
      case ProcessingForegroundProgressEvent():
        _safeCall(() => callbacks.onModelProgress?.call(event.progress));
      case ProcessingForegroundDoneEvent():
        _completer.complete(event.note);
      case ProcessingForegroundErrorEvent():
        _completer.completeError(event.error);
      case null:
        return;
    }
  }

  void _handleStep(ProcessingStep step) {
    _safeCall(() => callbacks.onStep?.call(step));
    if (step == ProcessingStep.summarizing) {
      _safeCall(() => onSummaryStep?.call());
    }
  }

  void _safeCall(void Function() callback) {
    try {
      callback();
    } catch (_) {}
  }
}
