import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:musicplayer/core/utils/utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class DownloadCancelledException implements Exception {
  const DownloadCancelledException();

  @override
  String toString() => 'Download cancelled';
}

class AudioDownloader {
  final http.Client _http = http.Client();
  final _log = Logger('AudioDownloader');

  File prepareFile(String savePath, String title, String extension) {
    final filePath = "$savePath/${Utils.sanitizeFileName('$title.$extension')}";
    final file = File(filePath);

    if (file.existsSync()) {
      file.deleteSync();
    }

    return file;
  }

  /// googlevideo returns 403 for stream URLs which require a PO token.
  /// Checking with HEAD fails fast instead of letting the stream client
  /// silently refetch the manifest before every 403 and never yield bytes.
  Future<bool> isServing(StreamInfo stream) async {
    try {
      final response = await _http.head(stream.url, headers: {
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.18 Safari/537.36',
      });
      return response.statusCode < 400;
    } on Exception {
      return false;
    }
  }

  /// Downloads the first candidate stream that is actually being served.
  /// Candidates are ordered by preference (audio-only preferred over muxed).
  Future<File> downloadFirstAvailable(
    List<StreamInfo> candidateStreams,
    Stream<List<int>> Function(StreamInfo stream) getStream,
    String savePath,
    String title, {
    void Function(int downloadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
    Future<void>? cancelSignal,
    Duration stallTimeout = const Duration(seconds: 60),
  }) async {
    Object? lastError;
    for (final stream in candidateStreams) {
      if (isCancelled?.call() ?? false) {
        throw const DownloadCancelledException();
      }
      final serving = await isServing(stream);
      _log.fine(
          "Stream ${stream.tag} (${stream.container.name}): serving=$serving");
      if (!serving) {
        lastError = "Stream ${stream.tag} is not serving bytes";
        continue;
      }

      try {
        final sourceFile = prepareFile(savePath, title, stream.container.name);
        await downloadAudioStream(
          () => getStream(stream),
          sourceFile,
          stream.size.totalBytes,
          onProgress: onProgress,
          isCancelled: isCancelled,
          cancelSignal: cancelSignal,
          stallTimeout: stallTimeout,
        );
        return sourceFile;
      } on DownloadCancelledException {
        rethrow;
      } catch (e) {
        lastError = "Stream ${stream.tag} failed: $e";
        _log.warning(lastError);
      }
    }
    throw Exception("Download failed: $lastError");
  }

  Future<void> downloadAudioStream(
    Stream<List<int>> Function() streamFactory,
    File file,
    int fileLength, {
    void Function(int downloadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
    Future<void>? cancelSignal,
    Duration stallTimeout = const Duration(seconds: 60),
  }) async {
    const maxAttempts = 3;

    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (isCancelled?.call() ?? false) {
        throw const DownloadCancelledException();
      }
      try {
        if (file.existsSync()) {
          file.deleteSync();
        }
        final output = file.openWrite();
        var dataDownloaded = 0;
        _log.fine(
            "Attempt $attempt: starting download of ${file.path} with expected size $fileLength bytes");

        StreamSubscription<List<int>>? subscription;
        Timer? stallTimer;
        final completer = Completer<void>();

        void resetStallTimer() {
          stallTimer?.cancel();
          stallTimer = Timer(stallTimeout, () {
            if (!completer.isCompleted) {
              completer.completeError(
                TimeoutException(
                    'Stream stalled for $stallTimeout', stallTimeout),
              );
            }
          });
        }

        try {
          resetStallTimer();
          cancelSignal?.then((_) {
            if (!completer.isCompleted) {
              completer.completeError(const DownloadCancelledException());
            }
          });

          subscription = streamFactory().listen(
            (data) {
              if (completer.isCompleted) return;
              if (isCancelled?.call() ?? false) {
                completer.completeError(const DownloadCancelledException());
                return;
              }
              resetStallTimer();
              dataDownloaded += data.length;
              onProgress?.call(dataDownloaded, fileLength);
              output.add(data);
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!completer.isCompleted) {
                completer.completeError(error, stackTrace);
              }
            },
            onDone: () {
              if (!completer.isCompleted) {
                completer.complete();
              }
            },
            cancelOnError: true,
          );

          await completer.future;
        } finally {
          stallTimer?.cancel();
          await subscription?.cancel();
          await output.close();
        }

        if (dataDownloaded < fileLength) {
          lastError =
              "Incomplete download: received $dataDownloaded of $fileLength bytes";
          _log.warning(lastError);
          continue;
        }
        return;
      } on DownloadCancelledException {
        if (file.existsSync()) {
          file.deleteSync();
        }
        rethrow;
      } catch (e) {
        lastError = "Attempt $attempt error: $e";
        _log.warning(lastError);
      }
    }

    if (file.existsSync()) {
      file.deleteSync();
    }
    throw Exception("Download failed: $lastError");
  }
}
