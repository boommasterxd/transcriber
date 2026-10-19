import 'package:test/test.dart';
import 'package:transcriber/services/summarization/summary_result.dart';

void main() {
  test('stores the structured summary fields supplied to the constructor', () {
    final points = ['Point one', 'Point two'];
    final todos = ['Action'];
    const title = 'Meeting';
    const gist = 'The meeting is scheduled.';

    final result = SummaryResult(
      title: title,
      gist: gist,
      points: points,
      todos: todos,
    );

    expect(result.title, title);
    expect(result.gist, gist);
    expect(result.points, same(points));
    expect(result.todos, same(todos));
  });

  test('supports an empty summary with const lists', () {
    const result = SummaryResult(
      title: 'Fallback',
      gist: '',
      points: <String>[],
      todos: <String>[],
    );

    expect(result.title, 'Fallback');
    expect(result.gist, isEmpty);
    expect(result.points, isEmpty);
    expect(result.todos, isEmpty);
  });
}
