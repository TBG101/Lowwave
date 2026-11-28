import 'package:flutter_test/flutter_test.dart';
import 'package:musicplayer/features/youtube/data/download_queue.dart';
import 'package:musicplayer/features/youtube/data/download_task.dart';

void main() {
  group('DownloadQueue.updateProgress', () {
    test(
        'only refreshes RxList when percent changes or totalBytes transitions from 0',
        () async {
      final queue = DownloadQueue.forTesting();
      final task = DownloadTask(
        videoId: 'vid1',
        title: 'Test Song',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      queue.tasks.add(task);

      var notifyCount = 0;
      final sub = queue.tasks.listen((_) => notifyCount++);
      addTearDown(sub.cancel);

      // 50 chunk updates at 0% with totalBytes transitioning from 0 -> 1000.
      for (var i = 1; i <= 50; i++) {
        queue.updateProgress(
          'vid1',
          percent: 0,
          downloadedBytes: i * 2,
          totalBytes: 1000,
        );
      }
      await Future<void>.delayed(Duration.zero);

      expect(notifyCount, 1);
      expect(task.downloadedBytes, 100);
      expect(task.totalBytes, 1000);

      // Distinct percent increments should each trigger a notification.
      queue.updateProgress('vid1', percent: 1, downloadedBytes: 110);
      queue.updateProgress('vid1', percent: 2, downloadedBytes: 120);
      await Future<void>.delayed(Duration.zero);

      expect(notifyCount, 3);
      expect(task.progress, 2);
      expect(task.downloadedBytes, 120);
    });
  });
}
