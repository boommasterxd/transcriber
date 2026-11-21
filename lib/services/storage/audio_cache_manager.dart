import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'bounded_audio_copy.dart';
import 'managed_audio_file.dart';
import 'staged_audio_retention.dart';
import 'storage_paths.dart';

export 'staged_audio_retention.dart';

/// Owns app-private audio imports, recordings, retained files, and cleanup.
final class AudioCacheManager {
  AudioCacheManager({
    Future<StoragePaths>? paths,
    DateTime Function()? now,
    Uuid? uuid,
    this.maximumFileBytes = 250 * 1024 * 1024,
    this.cacheQuotaBytes = 512 * 1024 * 1024,
    this.temporaryTtl = const Duration(hours: 24),
  }) : _paths = paths ?? StoragePaths.create(),
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final Future<StoragePaths> _paths;
  final DateTime Function() _now;
  final Uuid _uuid;
  final int maximumFileBytes;
  final int cacheQuotaBytes;
  final Duration temporaryTtl;
  final Set<String> _activePaths = {};

  static const supportedExtensions = {
    '.flac',
    '.mp3',
    '.mp4',
    '.mpeg',
    '.mpga',
    '.m4a',
    '.ogg',
    '.opus',
    '.wav',
    '.webm',
  };

  Future<ManagedAudioFile> importExternal(
    String sourcePath, {
    String? displayName,
  }) async {
    final source = File(sourcePath);
    await _validateSource(source);
    final extension = _validatedExtension(displayName ?? sourcePath);
    final directory = await (await _paths).importCacheDir();
    final destination = File(
      p.join(
        directory.path,
        '${_now().millisecondsSinceEpoch}_${_uuid.v4()}$extension',
      ),
    );
    try {
      await copyAudioWithinLimit(source, destination, maximumFileBytes);
      return ManagedAudioFile(
        path: destination.path,
        ownership: AudioOwnership.temporary,
      );
    } catch (_) {
      await _deleteQuietly(destination);
      rethrow;
    }
  }

  Future<ManagedAudioFile> registerShared(String path) async {
    final file = File(path);
    await _validateSource(file);
    final sharedDirectory = await (await _paths).sharedCacheDir();
    if (!await _isWithin(sharedDirectory, file)) {
      throw const FileSystemException('Shared audio is outside app cache');
    }
    return ManagedAudioFile(path: path, ownership: AudioOwnership.temporary);
  }

  Future<String> recordingDestination() async {
    final directory = await (await _paths).recordingCacheDir();
    return p.join(
      directory.path,
      'recording_${_now().millisecondsSinceEpoch}_${_uuid.v4()}.wav',
    );
  }

  Future<ManagedAudioFile> registerRecording(String path) async {
    final file = File(path);
    await _validateSource(file);
    final directory = await (await _paths).recordingCacheDir();
    if (!await _isWithin(directory, file)) {
      throw const FileSystemException('Recording is outside app cache');
    }
    return ManagedAudioFile(path: path, ownership: AudioOwnership.temporary);
  }

  Future<StagedAudioRetention> stageRetention(ManagedAudioFile audio) async {
    await validate(audio);
    final source = File(audio.path);
    final extension = _validatedExtension(source.path);
    final paths = await _paths;
    final retained = await paths.retainedAudioDir();
    final staging = await paths.retentionStagingDir();
    final name = '${_uuid.v4()}$extension';
    final stage = StagedAudioRetention(
      source: source,
      stage: File(p.join(staging.path, name)),
      destination: ManagedAudioFile(
        path: p.join(retained.path, name),
        ownership: AudioOwnership.retained,
      ),
      maximumBytes: maximumFileBytes,
    );
    await stage.prepare();
    return stage;
  }

  void markActive(ManagedAudioFile audio) =>
      _activePaths.add(_canonicalPath(File(audio.path)));

  void markInactive(ManagedAudioFile audio) =>
      _activePaths.remove(_canonicalPath(File(audio.path)));

  /// Validates size, format, and ownership before an upload starts.
  Future<void> validate(ManagedAudioFile audio) async {
    final file = File(audio.path);
    await _validateSource(file);
    if (audio.ownership != AudioOwnership.external &&
        !await _isOwned(file, audio.ownership)) {
      throw const FileSystemException('Audio is outside app-owned storage');
    }
  }

  Future<void> discard(ManagedAudioFile audio) async {
    await tryDiscard(audio);
  }

  /// Deletes app-owned audio when it is no longer active in this engine.
  ///
  /// Returns false when an active audio operation still owns the path. The
  /// caller can keep its durable deletion marker and retry during recovery.
  Future<bool> tryDiscard(ManagedAudioFile audio) async {
    if (audio.ownership == AudioOwnership.external) return true;
    final file = File(audio.path);
    if (_activePaths.contains(_canonicalPath(file))) return false;
    if (!await file.exists()) return true;
    if (!await _isOwned(file, audio.ownership)) return false;
    return _tryDeleteQuietly(file);
  }

  Future<void> deleteRetainedPath(String? path) async {
    await tryDeleteRetainedPath(path);
  }

  /// Attempts to delete a retained file without blocking an active operation.
  Future<bool> tryDeleteRetainedPath(String? path) async {
    if (path == null) return true;
    return tryDiscard(
      ManagedAudioFile(path: path, ownership: AudioOwnership.retained),
    );
  }

  Future<void> cleanup({bool enforceQuota = true}) async {
    final paths = await _paths;
    final directories = [
      await paths.importCacheDir(),
      await paths.sharedCacheDir(),
      await paths.recordingCacheDir(),
    ];
    final now = _now();
    final expiry = now.subtract(temporaryTtl);
    final eligible = <_CacheFile>[];
    await for (final file in _cacheFiles(directories)) {
      if (file.modified.isBefore(expiry) && await _deleteCacheEntry(file)) {
        continue;
      }
      if (enforceQuota && file.modified.isBefore(now)) eligible.add(file);
    }
    if (enforceQuota) await _enforceQuota(eligible);
    await for (final file in _cacheFiles([await paths.retentionStagingDir()])) {
      if (file.modified.isBefore(expiry)) await _deleteCacheEntry(file);
    }
  }

  Future<void> _validateSource(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.file) {
      throw FileSystemException('Audio file does not exist', file.path);
    }
    _validatedExtension(file.path);
    final size = await file.length();
    if (size <= 0 || size > maximumFileBytes) {
      throw FileSystemException('Audio file size is not supported', file.path);
    }
  }

  String _validatedExtension(String path) {
    final extension = p.extension(path).toLowerCase();
    if (!supportedExtensions.contains(extension)) {
      throw ArgumentError.value(path, 'path', 'Unsupported audio format');
    }
    return extension;
  }

  Future<bool> _isOwned(File file, AudioOwnership ownership) async {
    final paths = await _paths;
    if (ownership == AudioOwnership.retained) {
      return _isWithin(await paths.retainedAudioDir(), file);
    }
    return await _isWithin(await paths.importCacheDir(), file) ||
        await _isWithin(await paths.sharedCacheDir(), file) ||
        await _isWithin(await paths.recordingCacheDir(), file);
  }

  Future<bool> _isWithin(Directory root, File file) async {
    try {
      final resolvedRoot = await root.resolveSymbolicLinks();
      final resolvedFile = await file.resolveSymbolicLinks();
      return p.isWithin(p.normalize(resolvedRoot), p.normalize(resolvedFile));
    } on FileSystemException {
      return false;
    }
  }

  String _canonicalPath(FileSystemEntity entity) =>
      p.normalize(entity.absolute.path);

  Stream<_CacheFile> _cacheFiles(List<Directory> directories) async* {
    for (final directory in directories) {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || _activePaths.contains(_canonicalPath(entity))) {
          continue;
        }
        final stat = await entity.stat();
        yield _CacheFile(
          file: entity,
          size: stat.size,
          modified: stat.modified,
        );
      }
    }
  }

  Future<void> _enforceQuota(List<_CacheFile> files) async {
    var total = files.fold<int>(0, (sum, file) => sum + file.size);
    if (total <= cacheQuotaBytes) return;
    files.sort((a, b) => a.modified.compareTo(b.modified));
    for (final file in files) {
      if (await _deleteCacheEntry(file)) total -= file.size;
      if (total <= cacheQuotaBytes) return;
    }
  }

  Future<bool> _deleteCacheEntry(_CacheFile entry) async {
    if (_activePaths.contains(_canonicalPath(entry.file))) return false;
    return _tryDeleteQuietly(entry.file);
  }

  Future<void> _deleteQuietly(File file) async {
    await _tryDeleteQuietly(file);
  }

  Future<bool> _tryDeleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
      return true;
    } on FileSystemException {
      // Cleanup is best-effort; the next startup pass retries stale files.
      return false;
    }
  }
}

final class _CacheFile {
  const _CacheFile({
    required this.file,
    required this.size,
    required this.modified,
  });

  final File file;
  final int size;
  final DateTime modified;
}
