import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:musicplayer/core/utils/utils.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ThumbnailService {
  ThumbnailService({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  Future<Uint8List?> _downloadThumbnail(Video video) async {
    final urls = [
      video.thumbnails.maxResUrl,
      video.thumbnails.highResUrl,
      video.thumbnails.standardResUrl,
      video.thumbnails.mediumResUrl,
      video.thumbnails.lowResUrl,
    ];

    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        final client = _httpClient;
        final response =
            client != null ? await client.get(uri) : await http.get(uri);

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      } catch (_) {
        // Try the next thumbnail.
      }
    }

    return null;
  }

  Future<String?> saveThumbnail(
    Video video, {
    Directory? directory,
  }) async {
    final imgBytes = await _downloadThumbnail(video);

    if (imgBytes == null) {
      return null;
    }

    final targetDir = directory ?? Directory.systemTemp;
    final safeId = Utils.sanitizeFileName(video.id.toString());
    final imgPath = p.join(
      targetDir.path,
      '.cover_${safeId}_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );

    final file = File(imgPath);
    await file.writeAsBytes(imgBytes);

    return imgPath;
  }

  Future<Uint8List?> getThumbnailBytes(Video video) {
    return _downloadThumbnail(video);
  }
}
