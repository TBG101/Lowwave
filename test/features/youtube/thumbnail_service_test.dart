import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musicplayer/features/youtube/data/thumbnail_service.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _FakeVideo extends Fake implements Video {
  _FakeVideo(String videoId)
      : id = VideoId(videoId),
        thumbnails = ThumbnailSet(videoId);

  @override
  final VideoId id;

  @override
  final ThumbnailSet thumbnails;
}

void main() {
  group('ThumbnailService.saveThumbnail', () {
    test('falls back across thumbnail URLs without duplicates and writes file',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('thumb_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final requestedPaths = <String>[];
      final client = MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path.endsWith('/mqdefault.jpg')) {
          return http.Response.bytes([0xFF, 0xD8, 0xFF], 200);
        }
        return http.Response('not found', 404);
      });

      final service = ThumbnailService(httpClient: client);
      final video = _FakeVideo('dQw4w9WgXcQ');

      final savedPath = await service.saveThumbnail(video, directory: tempDir);

      expect(savedPath, isNotNull);
      expect(p.isWithin(tempDir.path, savedPath!), isTrue);
      expect(await File(savedPath).readAsBytes(), [0xFF, 0xD8, 0xFF]);
      expect(requestedPaths, [
        '/vi/dQw4w9WgXcQ/maxresdefault.jpg',
        '/vi/dQw4w9WgXcQ/hqdefault.jpg',
        '/vi/dQw4w9WgXcQ/sddefault.jpg',
        '/vi/dQw4w9WgXcQ/mqdefault.jpg',
      ]);
    });

    test('creates unique temp files on consecutive calls', () async {
      final tempDir = await Directory.systemTemp.createTemp('thumb_uniq_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = MockClient((request) async {
        return http.Response.bytes([1, 2, 3], 200);
      });

      final service = ThumbnailService(httpClient: client);
      final video = _FakeVideo('dQw4w9WgXcQ');

      final firstPath = await service.saveThumbnail(video, directory: tempDir);
      final secondPath = await service.saveThumbnail(video, directory: tempDir);

      expect(firstPath, isNotNull);
      expect(secondPath, isNotNull);
      expect(firstPath, isNot(equals(secondPath)));
      expect(File(firstPath!).existsSync(), isTrue);
      expect(File(secondPath!).existsSync(), isTrue);
    });

    test('returns null when all thumbnail URLs fail', () async {
      final tempDir = await Directory.systemTemp.createTemp('thumb_fail_');
      addTearDown(() => tempDir.delete(recursive: true));

      final client = MockClient((request) async => http.Response('err', 404));
      final service = ThumbnailService(httpClient: client);
      final video = _FakeVideo('dQw4w9WgXcQ');

      final savedPath = await service.saveThumbnail(video, directory: tempDir);
      expect(savedPath, isNull);
      expect(tempDir.listSync(), isEmpty);
    });
  });
}
