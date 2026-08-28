/// Structured summary produced from a transcript by a cloud model.
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
