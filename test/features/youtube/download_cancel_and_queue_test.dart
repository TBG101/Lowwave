import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:musicplayer/features/youtube/data/audio_downloader.dart';
import 'package:musicplayer/features/youtube/data/download_queue.dart';
import 'package:musicplayer/features/youtube/data/download_task.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _FakeStreamInfo extends Fake implements StreamInfo {
  _FakeStreamInfo({
    required this.tag,
    required this.url,
    required this.size,
  });

  @override
  final int tag;

  @override
  final Uri url;

  @override
  final StreamContainer container = StreamContainer.webM;

  @override
  final FileSize size;
}

void main() {
  group('AudioDownloader cancellation', () {
    test('cancelling a stalled stream aborts immediately and deletes partial',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('cancel_stall_');
      addTearDown(() => tempDir.delete(recursive: true));

      final downloader = AudioDownloader();
      final targetFile = File(p.join(tempDir.path, 'stalled.webm'));
      final streamController = StreamController<List<int>>();
      addTearDown(streamController.close);

      final token = DownloadCancelToken();
      final stopwatch = Stopwatch()..start();

      final downloadFuture = downloader.downloadAudioStream(
        () => streamController.stream,
        targetFile,
        1024,
        isCancelled: () => token.isCancelled,
        cancelSignal: token.onCancel,
        stallTimeout: const Duration(seconds: 30),
      );

      // Emit one partial chunk, then stall indefinitely.
      streamController.add([1, 2, 3]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel();

      await expectLater(
        downloadFuture,
        throwsA(isA<DownloadCancelledException>()),
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      expect(targetFile.existsSync(), isFalse);
    });

    test('downloadFirstAvailable throws before probing streams if cancelled',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('cancel_probe_');
      addTearDown(() => tempDir.delete(recursive: true));

      final downloader = AudioDownloader();
      final token = DownloadCancelToken()..cancel();
      final stream = _FakeStreamInfo(
        tag: 251,
        url: Uri.parse('https://example.com/videoplayback'),
        size: const FileSize(1024),
      );

      var getStreamCalled = false;
      await expectLater(
        downloader.downloadFirstAvailable(
          [stream],
          (_) {
            getStreamCalled = true;
            return const Stream.empty();
          },
          tempDir.path,
          'Cancelled Song',
          isCancelled: () => token.isCancelled,
          cancelSignal: token.onCancel,
        ),
        throwsA(isA<DownloadCancelledException>()),
      );
      expect(getStreamCalled, isFalse);
    });
  });

  group('DownloadQueue cancellation and re-queue isolation', () {
    test(
        're-queueing while prior attempt is unwinding isolates cancel token and status',
        () async {
      final queue = DownloadQueue.forTesting();
      final firstUnwindCompleter = Completer<void>();
      final firstStarted = Completer<void>();
      final secondStarted = Completer<void>();

      final task1 = DownloadTask(
        videoId: 'vid1',
        title: 'Song',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      queue.addTask(task1, () async {
        queue.setStatus('vid1', DownloadStatus.downloading, task: task1);
        firstStarted.complete();
        await firstUnwindCompleter.future;
        // Simulate old task attempting to mutate status after unwinding.
        queue.setStatus('vid1', DownloadStatus.failed, task: task1);
      });

      await firstStarted.future;
      queue.cancelTask('vid1');
      expect(task1.cancelToken.isCancelled, isTrue);
      expect(task1.status, DownloadStatus.cancelled);

      // Re-queue the same videoId before task1 finishes unwinding.
      final task2 = DownloadTask(
        videoId: 'vid1',
        title: 'Song',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      queue.addTask(task2, () async {
        queue.setStatus('vid1', DownloadStatus.downloading, task: task2);
        secondStarted.complete();
        queue.setStatus('vid1', DownloadStatus.completed, task: task2);
      });

      expect(task2.cancelToken.isCancelled, isFalse);
      expect(queue.isCancelled('vid1'), isFalse);

      // Let task1 finish unwinding; it must not overwrite task2's status.
      firstUnwindCompleter.complete();
      await secondStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(queue.byVideoId('vid1'), same(task2));
      expect(task2.status, DownloadStatus.completed);
    });

    test('clearFinished removes completed, failed, and cancelled tasks', () {
      final queue = DownloadQueue.forTesting();
      queue.tasks.addAll([
        DownloadTask(
          videoId: 'q',
          title: 'Queued',
          thumbnailUrl: '',
          status: DownloadStatus.queued,
        ),
        DownloadTask(
          videoId: 'd',
          title: 'Downloading',
          thumbnailUrl: '',
          status: DownloadStatus.downloading,
        ),
        DownloadTask(
          videoId: 'c1',
          title: 'Converting',
          thumbnailUrl: '',
          status: DownloadStatus.converting,
        ),
        DownloadTask(
          videoId: 'ok',
          title: 'Completed',
          thumbnailUrl: '',
          status: DownloadStatus.completed,
        ),
        DownloadTask(
          videoId: 'err',
          title: 'Failed',
          thumbnailUrl: '',
          status: DownloadStatus.failed,
        ),
        DownloadTask(
          videoId: 'can',
          title: 'Cancelled',
          thumbnailUrl: '',
          status: DownloadStatus.cancelled,
        ),
      ]);

      queue.clearFinished();

      expect(
        queue.tasks.map((t) => t.videoId).toList(),
        ['q', 'd', 'c1'],
      );
    });
  });
}
