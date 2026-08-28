import 'audio_ownership.dart';

/// Origin of an audio note.
enum NoteSource {
  shared('shared'),
  file('file'),
  recording('recording');

  const NoteSource(this.id);
  final String id;

  static NoteSource fromId(String? id) => NoteSource.values.firstWhere(
    (s) => s.id == id,
    orElse: () => NoteSource.file,
  );
}

/// A single time-stamped transcript line.
class TranscriptLine {
  const TranscriptLine({required this.time, required this.text});

  final String time;
  final String text;

  Map<String, dynamic> toJson() => {'time': time, 'text': text};
  factory TranscriptLine.fromJson(Map<String, dynamic> j) => TranscriptLine(
    time: j['time'] as String? ?? '',
    text: j['text'] as String? ?? '',
  );
}

/// A to-do / action item extracted from the audio.
class TodoItem {
  TodoItem({required this.text, this.done = false});

  final String text;
  bool done;

  Map<String, dynamic> toJson() => {'text': text, 'done': done};
  factory TodoItem.fromJson(Map<String, dynamic> j) => TodoItem(
    text: j['text'] as String? ?? '',
    done: j['done'] as bool? ?? false,
  );
}

/// A fully processed audio note: the audio reference plus the transcription and
/// the structured summary, and a record of which models produced it.
class TranscriptNote {
  TranscriptNote({
    required this.id,
    required this.title,
    required this.speaker,
    required this.source,
    required this.durationSec,
    required this.createdAt,
    required this.asrIsLocal,
    required this.summaryIsLocal,
    required this.asrName,
    required this.asrSub,
    required this.llmName,
    required this.llmSub,
    required this.gist,
    required this.points,
    required this.todos,
    required this.transcript,
    this.audioPath,
    this.audioOwnership = AudioOwnership.external,
  });

  final String id;
  final String title;
  final String speaker;
  final NoteSource source;
  final int durationSec;
  final DateTime createdAt;

  /// Historical processing origin. New notes always store `false` here.
  final bool asrIsLocal;
  final bool summaryIsLocal;

  /// Models used, with their secondary label (size / cloud / provider).
  final String asrName;
  final String asrSub;
  final String llmName;
  final String llmSub;

  final String gist;
  final List<String> points;
  final List<TodoItem> todos;
  final List<TranscriptLine> transcript;

  /// Local path of the (optionally retained) source audio file.
  final String? audioPath;
  final AudioOwnership audioOwnership;

  /// True if any stage ran in the cloud (used for the history dot color).
  bool get isRemote => !(asrIsLocal && summaryIsLocal);

  /// Compact model label used in the history list.
  String get modelShort => '$asrName · ${llmName.split(' · ').first}';

  String get fullTranscriptText =>
      transcript.map((l) => '[${l.time}] ${l.text}').join('\n');

  TranscriptNote copyWith({
    List<TodoItem>? todos,
    String? audioPath,
    AudioOwnership? audioOwnership,
  }) => TranscriptNote(
    id: id,
    title: title,
    speaker: speaker,
    source: source,
    durationSec: durationSec,
    createdAt: createdAt,
    asrIsLocal: asrIsLocal,
    summaryIsLocal: summaryIsLocal,
    asrName: asrName,
    asrSub: asrSub,
    llmName: llmName,
    llmSub: llmSub,
    gist: gist,
    points: points,
    todos: todos ?? this.todos,
    transcript: transcript,
    audioPath: audioPath ?? this.audioPath,
    audioOwnership: audioOwnership ?? this.audioOwnership,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'speaker': speaker,
    'source': source.id,
    'durationSec': durationSec,
    'createdAt': createdAt.toIso8601String(),
    'asrIsLocal': asrIsLocal,
    'summaryIsLocal': summaryIsLocal,
    'asrName': asrName,
    'asrSub': asrSub,
    'llmName': llmName,
    'llmSub': llmSub,
    'gist': gist,
    'points': points,
    'todos': todos.map((t) => t.toJson()).toList(),
    'transcript': transcript.map((t) => t.toJson()).toList(),
    'audioPath': audioPath,
    'audioOwnership': audioOwnership.id,
  };

  factory TranscriptNote.fromJson(Map<String, dynamic> j) => TranscriptNote(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    speaker: j['speaker'] as String? ?? '',
    source: NoteSource.fromId(j['source'] as String?),
    durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    asrIsLocal: j['asrIsLocal'] as bool? ?? (j['mode'] as String?) != 'remote',
    summaryIsLocal:
        j['summaryIsLocal'] as bool? ?? (j['mode'] as String?) != 'remote',
    asrName: j['asrName'] as String? ?? '',
    asrSub: j['asrSub'] as String? ?? '',
    llmName: j['llmName'] as String? ?? '',
    llmSub: j['llmSub'] as String? ?? '',
    gist: j['gist'] as String? ?? '',
    points:
        (j['points'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    todos:
        (j['todos'] as List?)
            ?.map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    transcript:
        (j['transcript'] as List?)
            ?.map((e) => TranscriptLine.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    audioPath: j['audioPath'] as String?,
    audioOwnership: AudioOwnership.fromId(j['audioOwnership'] as String?),
  );
}
