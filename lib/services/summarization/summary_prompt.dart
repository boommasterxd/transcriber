import 'dart:convert';

import 'summary_result.dart';

/// Builds the prompt used to turn a transcript into a structured summary, and
/// parses the model's JSON response. Shared by both the on-device (Gemma) and
/// cloud summarizers so the contract stays identical everywhere (DRY).
class SummaryPrompt {
  const SummaryPrompt._();

  static String system(bool german) => german
      ? 'Du bist ein präziser Assistent, der Sprachnachrichten zusammenfasst. '
          'Antworte ausschließlich mit gültigem JSON, keine Erklärungen, kein Markdown.'
      : 'You are a precise assistant that summarizes voice messages. '
          'Respond only with valid JSON, no explanations, no markdown.';

  static String user(String transcript, {required bool german}) {
    if (german) {
      return '''
Fasse die folgende transkribierte Sprachnachricht zusammen.
Gib NUR ein JSON-Objekt mit genau diesen Feldern zurück:
{
  "title": "kurzer Titel (max. 6 Wörter)",
  "gist": "1-2 Sätze Kernaussage",
  "points": ["wichtigste Kernpunkte als kurze Stichpunkte"],
  "todos": ["konkrete To-dos / Aufgaben, falls vorhanden"]
}
Wenn es keine To-dos gibt, gib eine leere Liste zurück. Schreibe auf Deutsch.

Transkript:
"""
$transcript
"""''';
    }
    return '''
Summarize the following transcribed voice message.
Return ONLY a JSON object with exactly these fields:
{
  "title": "short title (max 6 words)",
  "gist": "1-2 sentence core message",
  "points": ["the most important key points as short bullets"],
  "todos": ["concrete to-dos / action items, if any"]
}
If there are no to-dos, return an empty list. Write in English.

Transcript:
"""
$transcript
"""''';
  }

  /// Tolerant parser: extracts the first JSON object from [raw] (handling code
  /// fences and surrounding prose) and maps it to a [SummaryResult].
  static SummaryResult parse(String raw, {required String fallbackTitle}) {
    final jsonText = _extractJson(raw);
    Map<String, dynamic>? map;
    if (jsonText != null) {
      try {
        map = jsonDecode(jsonText) as Map<String, dynamic>;
      } catch (_) {
        map = null;
      }
    }

    if (map == null) {
      // Model didn't return JSON — degrade gracefully to a plain gist.
      return SummaryResult(
        title: fallbackTitle,
        gist: raw.trim(),
        points: const [],
        todos: const [],
      );
    }

    List<String> list(dynamic v) =>
        (v is List) ? v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() : const [];

    final title = (map['title'] as String?)?.trim();
    return SummaryResult(
      title: (title == null || title.isEmpty) ? fallbackTitle : title,
      gist: (map['gist'] as String?)?.trim() ?? '',
      points: list(map['points']),
      todos: list(map['todos']),
    );
  }

  static String? _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return raw.substring(start, end + 1);
  }
}
