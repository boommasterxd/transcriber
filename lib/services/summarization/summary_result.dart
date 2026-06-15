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
}
