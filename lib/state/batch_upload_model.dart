import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';

enum BatchFileStatus { queued, decoding, transcribing, done, error }

class BatchFileEntry {
  final String path;
  final String filename;
  final BatchFileStatus status;
  final String? error;

  const BatchFileEntry({
    required this.path,
    required this.filename,
    this.status = BatchFileStatus.queued,
    this.error,
  });

  BatchFileEntry copyWith({BatchFileStatus? status, String? error}) {
    return BatchFileEntry(
      path: path,
      filename: filename,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

class BatchUploadNotifier extends StateNotifier<List<BatchFileEntry>> {
  BatchUploadNotifier() : super(const []);

  static const _supportedExtensions = {
    'wav', 'mp3', 'm4a', 'aac', 'ogg', 'flac', 'opus', 'mp4', 'mov', 'mkv',
  };

  /// Returns the paths that were rejected as unsupported formats.
  List<String> addFiles(List<String> paths) {
    final rejected = <String>[];
    final accepted = <BatchFileEntry>[];
    final existingPaths = state.map((entry) => entry.path).toSet();

    for (final path in paths) {
      final ext = path.split('.').last.toLowerCase();
      if (!_supportedExtensions.contains(ext)) {
        rejected.add(path);
        continue;
      }
      if (existingPaths.contains(path) || accepted.any((entry) => entry.path == path)) {
        continue;
      }
      accepted.add(BatchFileEntry(path: path, filename: path.split('/').last));
    }

    if (accepted.isNotEmpty) {
      state = [...state, ...accepted];
    }
    return rejected;
  }

  void updateStatus(String path, BatchFileStatus status, {String? error}) {
    state = [
      for (final entry in state)
        if (entry.path == path) entry.copyWith(status: status, error: error) else entry,
    ];
  }

  void clear() {
    state = const [];
  }

  void removeDone() {
    state = state.where((e) => e.status != BatchFileStatus.done).toList();
  }

  /// Process all queued files through the Rust engine sequentially.
  Future<void> processBatch(RustBridge bridge, String modelPath, {String? language}) async {
    final paths = state
        .where((e) => e.status == BatchFileStatus.queued)
        .map((e) => e.path)
        .toList();
    if (paths.isEmpty) return;

    for (final path in paths) {
      updateStatus(path, BatchFileStatus.transcribing);
      // Small delay so the UI can update before blocking on transcription
      await Future.delayed(const Duration(milliseconds: 50));
      try {
        final results = await bridge.batchTranscribeFiles(
          modelPath: modelPath,
          files: [path],
          language: language,
        );
        if (results.isNotEmpty) {
          updateStatus(path, BatchFileStatus.done);
        } else {
          updateStatus(path, BatchFileStatus.error, error: 'No speech detected');
        }
      } catch (e) {
        updateStatus(path, BatchFileStatus.error, error: e.toString());
      }
    }
  }
}

final batchUploadProvider = StateNotifierProvider<BatchUploadNotifier, List<BatchFileEntry>>((ref) {
  return BatchUploadNotifier();
});
