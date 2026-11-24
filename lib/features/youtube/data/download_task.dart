import 'dart:async';

enum DownloadStatus {
  queued,
  downloading,
  converting,
  completed,
  failed,
  cancelled
}

class DownloadCancelToken {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  Future<void> get onCancel => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

class DownloadTask {
  DownloadTask({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    DownloadCancelToken? cancelToken,
  }) : cancelToken = cancelToken ?? DownloadCancelToken();

  final String videoId;
  final String title;
  final String thumbnailUrl;
  final DownloadCancelToken cancelToken;
  DownloadStatus status;
  int progress;
  int downloadedBytes;
  int totalBytes;
}
