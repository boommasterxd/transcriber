import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transcript_note.dart';

/// Persists the list of processed [TranscriptNote]s as JSON.
class NotesRepository {
  NotesRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'notes';

  List<TranscriptNote> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => TranscriptNote.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<TranscriptNote> notes) async {
    await _prefs.setString(_key, jsonEncode(notes.map((n) => n.toJson()).toList()));
  }
}
