import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'download_task.dart';

class DownloadQueue {
  // singleton
  DownloadQueue._privateConstructor();
  static final DownloadQueue _instance = DownloadQueue._privateConstructor();
  factory DownloadQueue() {
    return _instance;
  }

  @visibleForTesting
  DownloadQueue.forTesting();

  final RxList<DownloadTask> tasks = <DownloadTask>[].obs;
  final List<(DownloadTask task, Future<void> Function() action)> _pending = [];
  bool downloading = false;

  void addTask(DownloadTask task, Future<void> Function() action) {
    tasks.removeWhere((t) => t.videoId == task.videoId);
    _pending.removeWhere((entry) => entry.$1.videoId == task.videoId);
    tasks.add(task);
    _pending.add((task, action));
    startQuee();
  }

  Future<void> startQuee() async {
    if (downloading == true) return;
    downloading = true;
    while (_pending.isNotEmpty) {
      final (task, action) = _pending.removeAt(0);
      if (task.cancelToken.isCancelled) continue;
      try {
        await action();
      } catch (e) {
        debugPrint('Download task crashed: $e');
      }
    }
    downloading = false;
  }

  bool isCancelled(String videoId) =>
      byVideoId(videoId)?.cancelToken.isCancelled ?? false;

  void cancelTask(String videoId) {
    final task = byVideoId(videoId);
    if (task == null) return;
    const activeStatuses = {
      DownloadStatus.queued,
      DownloadStatus.downloading,
      DownloadStatus.converting,
    };
    if (!activeStatuses.contains(task.status)) return;
    _pending.removeWhere((entry) => identical(entry.$1, task));
    task.cancelToken.cancel();
    task.status = DownloadStatus.cancelled;
    tasks.refresh();
  }

  DownloadTask? byVideoId(String videoId) {
    for (final task in tasks) {
      if (task.videoId == videoId) return task;
    }
    return null;
  }

  void setStatus(String videoId, DownloadStatus status, {DownloadTask? task}) {
    final current = byVideoId(videoId);
    if (current == null) return;
    if (task != null && !identical(current, task)) return;
    current.status = status;
    tasks.refresh();
  }

  void updateProgress(
    String videoId, {
    DownloadTask? task,
    int? percent,
    int? downloadedBytes,
    int? totalBytes,
  }) {
    final current = byVideoId(videoId);
    if (current == null) return;
    if (task != null && !identical(current, task)) return;
    var changed = false;
    if (percent != null && current.progress != percent) {
      current.progress = percent;
      changed = true;
    }
    if (downloadedBytes != null && current.downloadedBytes != downloadedBytes) {
      current.downloadedBytes = downloadedBytes;
      changed = true;
    }
    if (totalBytes != null && current.totalBytes != totalBytes) {
      current.totalBytes = totalBytes;
      changed = true;
    }
    if (changed) tasks.refresh();
  }

  void clearFinished() {
    tasks.removeWhere((t) =>
        t.status == DownloadStatus.completed ||
        t.status == DownloadStatus.failed ||
        t.status == DownloadStatus.cancelled);
  }
}
