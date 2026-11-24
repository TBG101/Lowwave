import 'dart:convert';
import 'dart:io';
import 'package:musicplayer/core/services/media_scanner.dart';

class Utils {
  static Future<void> androidScanMediaTrigger(String? mp3FilePath) async {
    if (mp3FilePath == null) return;
    await MediaScanner.scanFile(mp3FilePath);
  }

  static String sanitizeFileName(String input, {int maxBytes = 255}) {
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    final sanitized = input.replaceAll(invalidChars, '_');

    if (utf8.encode(sanitized).length <= maxBytes) {
      return sanitized;
    }

    final buffer = StringBuffer();
    var byteCount = 0;
    for (final rune in sanitized.runes) {
      final char = String.fromCharCode(rune);
      final charBytes = utf8.encode(char).length;
      if (byteCount + charBytes > maxBytes) {
        break;
      }
      buffer.write(char);
      byteCount += charBytes;
    }

    return buffer.toString();
  }

  static Future<void> deleteMusicUri(Uri uri) async {
    if (uri.scheme == 'content') {
      // MediaStore entry: delete through the content resolver so the file and
      // its MediaStore row both go away.
      await MediaScanner.deleteMedia(uri.toString());
    } else {
      await File.fromUri(uri).delete();
    }
  }

  static String formatDurationToMinutesAndSeconds(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}
