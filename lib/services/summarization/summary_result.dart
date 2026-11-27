/// Structured summary produced from a transcript by a cloud model.
class SummaryResult {
  const SummaryResult({
    required this.title,
    required this.gist,
    required this.points,
    required this.todos,
    this.titleIsAiGenerated = false,
  });

  final String title;
  final bool titleIsAiGenerated;
  final String gist;
  final List<String> points;
  final List<String> todos;
}
