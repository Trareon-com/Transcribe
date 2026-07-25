import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/state/batch_upload_model.dart';

void main() {
  group('BatchUploadNotifier', () {
    test('accepts supported formats and queues them', () {
      final notifier = BatchUploadNotifier();
      final rejected = notifier.addFiles(['/a/rapat.mp3', '/a/wawancara.wav']);

      expect(rejected, isEmpty);
      expect(notifier.state, hasLength(2));
      expect(notifier.state.every((e) => e.status == BatchFileStatus.queued), isTrue);
    });

    test('rejects unsupported formats without queuing them', () {
      final notifier = BatchUploadNotifier();
      final rejected = notifier.addFiles(['/a/document.pdf', '/a/song.mp3']);

      expect(rejected, ['/a/document.pdf']);
      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.filename, 'song.mp3');
    });

    test('updateStatus transitions a specific file only', () {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/one.mp3', '/a/two.mp3']);

      notifier.updateStatus('/a/one.mp3', BatchFileStatus.done);

      final one = notifier.state.firstWhere((e) => e.path == '/a/one.mp3');
      final two = notifier.state.firstWhere((e) => e.path == '/a/two.mp3');
      expect(one.status, BatchFileStatus.done);
      expect(two.status, BatchFileStatus.queued);
    });

    test('updateStatus records error message', () {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/corrupt.wav']);

      notifier.updateStatus('/a/corrupt.wav', BatchFileStatus.error, error: 'File tidak bisa dibaca');

      expect(notifier.state.single.status, BatchFileStatus.error);
      expect(notifier.state.single.error, 'File tidak bisa dibaca');
    });

    test('removeDone drops only completed entries', () {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/one.mp3', '/a/two.mp3']);
      notifier.updateStatus('/a/one.mp3', BatchFileStatus.done);

      notifier.removeDone();

      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.filename, 'two.mp3');
    });

    test('clear empties the queue', () {
      final notifier = BatchUploadNotifier();
      notifier.addFiles(['/a/one.mp3']);
      notifier.clear();
      expect(notifier.state, isEmpty);
    });

    test('extension matching is case-insensitive', () {
      final notifier = BatchUploadNotifier();
      final rejected = notifier.addFiles(['/a/RAPAT.MP3']);
      expect(rejected, isEmpty);
      expect(notifier.state, hasLength(1));
    });
  });
}
