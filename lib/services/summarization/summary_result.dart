/// Structured summary produced from a transcript by either an on-device or
/// cloud model.
class SummaryResult {
  const SummaryResult({
    required this.title,
    required this.gist,
    required this.points,
    required this.todos,
  });

  final String title;
  final String gist;
  final List<String> points;
  final List<String> todos;

  /// Serializes to a plain map for transfer across isolates (the on-device
  /// summary runs in a foreground-service isolate, see [GemmaForegroundService]).
  Map<String, Object?> toMap() => {
        'title': title,
        'gist': gist,
        'points': points,
        'todos': todos,
      };

  factory SummaryResult.fromMap(Map<String, dynamic> map) => SummaryResult(
        title: map['title'] as String? ?? '',
        gist: map['gist'] as String? ?? '',
        points: (map['points'] as List?)?.cast<String>() ?? const [],
        todos: (map['todos'] as List?)?.cast<String>() ?? const [],
      );
}
