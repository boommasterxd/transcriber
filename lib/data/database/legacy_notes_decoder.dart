import 'dart:convert';
import 'dart:isolate';

import '../models/transcript_note.dart';

/// A null rejection list means the source preference must be preserved.
typedef LegacyNotes = ({List<TranscriptNote> values, List<Object?>? rejected});

const LegacyNotes _preserveSource = (values: [], rejected: null);

/// Partitions and sorts the legacy notes using only the local JSON snapshot.
Future<LegacyNotes> decodeLegacyNotes(
  String? raw, {
  required bool includeValues,
}) async {
  if (raw == null) return _preserveSource;
  return Isolate.run(() => _decodeNotes(raw, includeValues));
}

LegacyNotes _decodeNotes(String raw, bool includeValues) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return _preserveSource;

    final values = <TranscriptNote>[];
    final rejected = <Object?>[];
    final ids = <String>{};
    for (final value in decoded) {
      final note = _tryReadNote(value, ids);
      if (note == null) {
        rejected.add(value);
      } else if (includeValues) {
        values.add(note);
      }
    }
    if (ids.isEmpty && rejected.isNotEmpty) return _preserveSource;
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (values: values, rejected: rejected);
  } catch (_) {
    return _preserveSource;
  }
}

TranscriptNote? _tryReadNote(Object? value, Set<String> ids) {
  try {
    final json = _validatedNoteJson(value);
    final note = TranscriptNote.fromJson(json);
    return ids.add(note.id) ? note : null;
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _validatedNoteJson(Object? value) {
  if (value is! Map) throw const FormatException('note object');
  final json = value.cast<String, dynamic>();
  final id = json['id'];
  if (id is! String || id.isEmpty) throw const FormatException('note id');
  final createdAt = json['createdAt'];
  if (createdAt is! String || DateTime.tryParse(createdAt) == null) {
    throw const FormatException('note timestamp');
  }
  return json;
}

Future<String> mergeLegacyRecoveryRecords(
  Object? current,
  List<Object?> rejected,
) => Isolate.run(() => _mergeRecoveryRecords(current, rejected));

String _mergeRecoveryRecords(Object? current, List<Object?> rejected) {
  final existing = _readRecoveryRecords(current);
  final seen = existing.map(jsonEncode).toSet();
  final additions = rejected.where((record) => seen.add(jsonEncode(record)));
  return jsonEncode([...existing, ...additions]);
}

List<Object?> _readRecoveryRecords(Object? value) {
  if (value == null) return [];
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded;
    } on FormatException {
      // Preserve unfamiliar prior recovery data as a separate record.
    }
  }
  return [
    {'unparsedRecoveryValue': value.toString()},
  ];
}
