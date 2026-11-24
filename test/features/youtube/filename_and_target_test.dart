import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:musicplayer/core/utils/utils.dart';
import 'package:musicplayer/features/youtube/data/audio_converter.dart';
import 'package:musicplayer/features/youtube/data/audio_downloader.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Utils.sanitizeFileName', () {
    test('truncates long ASCII titles to maxBytes', () {
      final longTitle = 'a' * 300;
      final sanitized = Utils.sanitizeFileName(longTitle);
      expect(utf8.encode(sanitized).length, 255);
      expect(sanitized.length, 255);
    });

    test('truncates multi-byte UTF-8 runes without exceeding maxBytes', () {
      // Each emoji is 4 UTF-8 bytes; 70 emojis = 280 bytes.
      final emojiTitle = '🎵' * 70;
      final sanitized = Utils.sanitizeFileName(emojiTitle, maxBytes: 255);
      final encoded = utf8.encode(sanitized);

      expect(encoded.length, lessThanOrEqualTo(255));
      expect(encoded.length, 252);
      expect(utf8.decode(encoded), sanitized);
    });

    test('truncates 3-byte CJK runes safely', () {
      final cjkTitle = '音楽' * 100; // 200 chars = 600 bytes
      final sanitized = Utils.sanitizeFileName(cjkTitle, maxBytes: 240);

      expect(utf8.encode(sanitized).length, 240);
      expect(sanitized.length, 80);
    });
  });

  group('AudioDownloader.prepareFile', () {
    test('preserves extension and keeps filename <= 255 UTF-8 bytes', () async {
      final tempDir = await Directory.systemTemp.createTemp('prepare_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final downloader = AudioDownloader();
      final longEmojiTitle = '🎶' * 100;
      final file = downloader.prepareFile(tempDir.path, longEmojiTitle, 'webm');

      final fileName = p.basename(file.path);
      expect(fileName.endsWith('.webm'), isTrue);
      expect(utf8.encode(fileName).length, lessThanOrEqualTo(255));
    });
  });

  group('AudioConverter.resolveTargetFile', () {
    test('reuses existing target when replacePath matches preferred path',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('target_replace_');
      addTearDown(() => tempDir.delete(recursive: true));

      final existing = File(p.join(tempDir.path, 'My Song.mp3'));
      await existing.writeAsBytes([1, 2, 3]);

      final converter = AudioConverter();
      final resolved = await converter.resolveTargetFile(
        tempDir.path,
        'My Song',
        replacePath: existing.path,
      );

      expect(resolved.path, existing.path);
    });

    test('appends numeric suffix when file exists and replacePath is absent',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('target_unique_');
      addTearDown(() => tempDir.delete(recursive: true));

      final existing = File(p.join(tempDir.path, 'My Song.mp3'));
      await existing.writeAsBytes([1, 2, 3]);

      final converter = AudioConverter();
      final resolved = await converter.resolveTargetFile(
        tempDir.path,
        'My Song',
      );

      expect(resolved.path, p.join(tempDir.path, 'My Song (2).mp3'));
    });

    test('appends numeric suffix when replacePath points to a different file',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('target_diff_');
      addTearDown(() => tempDir.delete(recursive: true));

      final existing = File(p.join(tempDir.path, 'My Song.mp3'));
      await existing.writeAsBytes([1, 2, 3]);

      final converter = AudioConverter();
      final resolved = await converter.resolveTargetFile(
        tempDir.path,
        'My Song',
        replacePath: p.join(tempDir.path, 'Other.mp3'),
      );

      expect(resolved.path, p.join(tempDir.path, 'My Song (2).mp3'));
    });
  });
}
