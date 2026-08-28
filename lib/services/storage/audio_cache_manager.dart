import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'managed_audio_file.dart';
import 'storage_paths.dart';

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
      await source.openRead().pipe(destination.openWrite());
      await _validateSource(destination);
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
    if (!_isWithin(sharedDirectory, file)) {
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
    if (!_isWithin(directory, file)) {
      throw const FileSystemException('Recording is outside app cache');
    }
    return ManagedAudioFile(path: path, ownership: AudioOwnership.temporary);
  }

  Future<ManagedAudioFile> retain(
    ManagedAudioFile audio, {
    bool deleteTemporarySource = true,
  }) async {
    if (audio.ownership == AudioOwnership.retained) return audio;
    final source = File(audio.path);
    await _validateSource(source);
    final extension = _validatedExtension(source.path);
    final directory = await (await _paths).retainedAudioDir();
    final destination = File(p.join(directory.path, '${_uuid.v4()}$extension'));
    try {
      await source.openRead().pipe(destination.openWrite());
      await _validateSource(destination);
    } catch (_) {
      await _deleteQuietly(destination);
      rethrow;
    }
    if (deleteTemporarySource && audio.ownership == AudioOwnership.temporary) {
      await discard(audio);
    }
    return ManagedAudioFile(
      path: destination.path,
      ownership: AudioOwnership.retained,
    );
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
    if (audio.ownership == AudioOwnership.external) return;
    final file = File(audio.path);
    if (_activePaths.contains(_canonicalPath(file))) return;
    if (!await _isOwned(file, audio.ownership)) return;
    await _deleteQuietly(file);
  }

  Future<void> deleteRetainedPath(String? path) async {
    if (path == null) return;
    await discard(
      ManagedAudioFile(path: path, ownership: AudioOwnership.retained),
    );
  }

  Future<void> cleanup() async {
    final paths = await _paths;
    final directories = [
      await paths.importCacheDir(),
      await paths.sharedCacheDir(),
      await paths.recordingCacheDir(),
    ];
    final files = await _cacheFiles(directories);
    final expiry = _now().subtract(temporaryTtl);
    for (final file in files) {
      if (file.modified.isBefore(expiry)) await _deleteCacheEntry(file);
    }
    await _enforceQuota(await _cacheFiles(directories));
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
    return _isWithin(await paths.importCacheDir(), file) ||
        _isWithin(await paths.sharedCacheDir(), file) ||
        _isWithin(await paths.recordingCacheDir(), file);
  }

  bool _isWithin(Directory root, File file) =>
      p.isWithin(_canonicalPath(root), _canonicalPath(file));

  String _canonicalPath(FileSystemEntity entity) =>
      p.normalize(entity.absolute.path);

  Future<List<_CacheFile>> _cacheFiles(List<Directory> directories) async {
    final result = <_CacheFile>[];
    for (final directory in directories) {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || _activePaths.contains(_canonicalPath(entity))) {
          continue;
        }
        final stat = await entity.stat();
        result.add(
          _CacheFile(file: entity, size: stat.size, modified: stat.modified),
        );
      }
    }
    return result;
  }

  Future<void> _enforceQuota(List<_CacheFile> files) async {
    var total = files.fold<int>(0, (sum, file) => sum + file.size);
    if (total <= cacheQuotaBytes) return;
    files.sort((a, b) => a.modified.compareTo(b.modified));
    for (final file in files) {
      await _deleteCacheEntry(file);
      total -= file.size;
      if (total <= cacheQuotaBytes) return;
    }
  }

  Future<void> _deleteCacheEntry(_CacheFile entry) =>
      _deleteQuietly(entry.file);

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Cleanup is best-effort; the next startup pass retries stale files.
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
