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

/// A single transcript line.
class TranscriptLine {
  const TranscriptLine({required this.text});

  final String text;

  Map<String, dynamic> toJson() => {'text': text};
  factory TranscriptLine.fromJson(Map<String, dynamic> j) =>
      TranscriptLine(text: j['text'] as String? ?? '');
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

/// Identification and recording metadata, independent of generated content.
class NoteMetadata {
  const NoteMetadata({
    required this.id,
    required this.title,
    required this.speaker,
    required this.source,
    required this.durationSec,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String speaker;
  final NoteSource source;
  final int durationSec;
  final DateTime createdAt;
}

/// Models and historical processing locations used to create the note.
class NoteOrigins {
  const NoteOrigins({
    required this.asrIsLocal,
    required this.summaryIsLocal,
    required this.asrName,
    required this.asrSub,
    required this.llmName,
    required this.llmSub,
  });

  /// Historical processing origin. New notes always store `false` here.
  final bool asrIsLocal;
  final bool summaryIsLocal;

  /// Models used, with their secondary label (size / cloud / provider).
  final String asrName;
  final String asrSub;
  final String llmName;
  final String llmSub;
}

/// Transcript and optional generated summary, including a safe diagnostic.
class NoteContent {
  const NoteContent({
    required this.gist,
    required this.points,
    required this.todos,
    required this.transcript,
    this.summaryError,
  });

  final String gist;
  final List<String> points;
  final List<TodoItem> todos;
  final List<TranscriptLine> transcript;

  /// Safe user-facing failure message when optional summarization failed.
  final String? summaryError;
}

/// Shared display metadata for lightweight history entries and full notes.
mixin NoteDisplayMetadata {
  NoteMetadata get metadata;
  NoteOrigins get origins;

  String get id => metadata.id;
  String get title => metadata.title;
  String get speaker => metadata.speaker;
  NoteSource get source => metadata.source;
  int get durationSec => metadata.durationSec;
  DateTime get createdAt => metadata.createdAt;

  /// True if any stage ran in the cloud (used for the history dot color).
  bool get isRemote => !(origins.asrIsLocal && origins.summaryIsLocal);

  /// Compact model label used in the history list.
  String get modelShort =>
      '${origins.asrName} · ${origins.llmName.split(' · ').first}';
}

/// A transcribed audio note with optional summary and retained source audio.
class TranscriptNote with NoteDisplayMetadata {
  TranscriptNote({
    required this.metadata,
    required this.content,
    required this.origins,
    this.audioPath,
    this.audioOwnership = AudioOwnership.external,
  });

  @override
  final NoteMetadata metadata;
  final NoteContent content;
  @override
  final NoteOrigins origins;

  bool get asrIsLocal => origins.asrIsLocal;
  bool get summaryIsLocal => origins.summaryIsLocal;
  String get asrName => origins.asrName;
  String get asrSub => origins.asrSub;
  String get llmName => origins.llmName;
  String get llmSub => origins.llmSub;
  String get gist => content.gist;
  List<String> get points => content.points;
  List<TodoItem> get todos => content.todos;
  List<TranscriptLine> get transcript => content.transcript;
  String? get summaryError => content.summaryError;

  /// Local path of the (optionally retained) source audio file.
  final String? audioPath;
  final AudioOwnership audioOwnership;

  String get fullTranscriptText =>
      transcript.map((line) => line.text).join('\n');

  TranscriptNote copyWith({
    List<TodoItem>? todos,
    String? audioPath,
    AudioOwnership? audioOwnership,
    String? summaryError,
  }) => TranscriptNote(
    metadata: metadata,
    origins: origins,
    content: NoteContent(
      gist: gist,
      points: points,
      todos: todos ?? this.todos,
      transcript: transcript,
      summaryError: summaryError ?? this.summaryError,
    ),
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
    'summaryError': summaryError,
    'audioPath': audioPath,
    'audioOwnership': audioOwnership.id,
  };

  factory TranscriptNote.fromJson(Map<String, dynamic> j) => TranscriptNote(
    metadata: NoteMetadata(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      speaker: j['speaker'] as String? ?? '',
      source: NoteSource.fromId(j['source'] as String?),
      durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    ),
    origins: NoteOrigins(
      asrIsLocal:
          j['asrIsLocal'] as bool? ?? (j['mode'] as String?) != 'remote',
      summaryIsLocal:
          j['summaryIsLocal'] as bool? ?? (j['mode'] as String?) != 'remote',
      asrName: j['asrName'] as String? ?? '',
      asrSub: j['asrSub'] as String? ?? '',
      llmName: j['llmName'] as String? ?? '',
      llmSub: j['llmSub'] as String? ?? '',
    ),
    content: NoteContent(
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
      summaryError: j['summaryError'] as String?,
    ),
    audioPath: j['audioPath'] as String?,
    audioOwnership: AudioOwnership.fromId(j['audioOwnership'] as String?),
  );
}
