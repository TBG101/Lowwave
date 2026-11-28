import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musicplayer/features/youtube/data/audio_downloader.dart';
import 'package:musicplayer/features/youtube/data/youtube_stream_client.dart';
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

_FakeStreamInfo _makeStream({
  required int tag,
  required String url,
  required int totalBytes,
}) {
  return _FakeStreamInfo(
    tag: tag,
    url: Uri.parse(url),
    size: FileSize(totalBytes),
  );
}

void main() {
  group('AudioDownloader.isServing', () {
    test('sends AndroidStreamHttpClient.androidUserAgent in HEAD request',
        () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('', 200);
      });

      final downloader = AudioDownloader(httpClient: client);
      final stream = _makeStream(
        tag: 251,
        url: 'https://rr1---sn-test.googlevideo.com/videoplayback?itag=251',
        totalBytes: 1024,
      );

      final result = await downloader.isServing(stream);

      expect(result, isTrue);
      expect(captured.method, 'HEAD');
      expect(
        captured.headers['user-agent'],
        AndroidStreamHttpClient.androidUserAgent,
      );
    });

    test('returns false for 403 responses and true for < 400', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['itag'] == '251') {
          return http.Response('', 403);
        }
        return http.Response('', 200);
      });

      final downloader = AudioDownloader(httpClient: client);
      final blocked = _makeStream(
        tag: 251,
        url: 'https://rr1---sn-test.googlevideo.com/videoplayback?itag=251',
        totalBytes: 1024,
      );
      final ok = _makeStream(
        tag: 18,
        url: 'https://rr1---sn-test.googlevideo.com/videoplayback?itag=18',
        totalBytes: 1024,
      );

      expect(await downloader.isServing(blocked), isFalse);
      expect(await downloader.isServing(ok), isTrue);
    });

    test('returns false when HEAD throws an exception', () async {
      final client = MockClient((request) async {
        throw const SocketException('network unreachable');
      });

      final downloader = AudioDownloader(httpClient: client);
      final stream = _makeStream(
        tag: 251,
        url: 'https://rr1---sn-test.googlevideo.com/videoplayback?itag=251',
        totalBytes: 1024,
      );

      expect(await downloader.isServing(stream), isFalse);
    });

    test('downloadFirstAvailable skips 403 stream and downloads serving stream',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('audio_dl_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = MockClient((request) async {
        if (request.url.queryParameters['itag'] == '251') {
          return http.Response('', 403);
        }
        return http.Response('', 200);
      });

      final downloader = AudioDownloader(httpClient: client);
      final blocked = _makeStream(
        tag: 251,
        url: 'https://rr1---sn-test.googlevideo.com/videoplayback?itag=251',
        totalBytes: 5,
      );
      final fallback = _makeStream(
        tag: 18,
        url: 'https://rr1---sn-test.googlevideo.com/videoplayback?itag=18',
        totalBytes: 5,
      );

      final requestedTags = <int>[];
      final file = await downloader.downloadFirstAvailable(
        [blocked, fallback],
        (stream) {
          requestedTags.add(stream.tag);
          return Stream.value([1, 2, 3, 4, 5]);
        },
        tempDir.path,
        'Test Track',
      );

      expect(requestedTags, [18]);
      expect(await file.readAsBytes(), [1, 2, 3, 4, 5]);
    });
  });
}
