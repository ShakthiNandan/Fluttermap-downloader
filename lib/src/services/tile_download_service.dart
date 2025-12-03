import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../utils/tile_calculator.dart';

/// Service for downloading map tiles
class TileDownloadService {
  final http.Client _client;
  bool _isPaused = false;
  bool _isCancelled = false;

  TileDownloadService({http.Client? client}) : _client = client ?? http.Client();

  /// Get the tiles directory path
  Future<Directory> getTilesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tilesDir = Directory('${appDir.path}/tiles');
    if (!await tilesDir.exists()) {
      await tilesDir.create(recursive: true);
    }
    return tilesDir;
  }

  /// Download a single tile with retry logic
  Future<bool> downloadTile(
    TileCoordinate tile,
    Directory tilesDir, {
    int retryCount = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    final url = TileCalculator.getTileUrl(tile);
    final tilePath = '${tilesDir.path}/${tile.path}';
    final tileFile = File(tilePath);

    // Create directory structure
    final tileDir = tileFile.parent;
    if (!await tileDir.exists()) {
      await tileDir.create(recursive: true);
    }

    for (int attempt = 0; attempt < retryCount; attempt++) {
      try {
        final response = await _client.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'OfflineMapTilesDownloader/1.0',
          },
        );

        if (response.statusCode == 200) {
          await tileFile.writeAsBytes(response.bodyBytes);
          return true;
        }
      } catch (e) {
        if (attempt < retryCount - 1) {
          await Future.delayed(retryDelay);
        }
      }
    }
    return false;
  }

  /// Download tiles in batches with progress callback
  Stream<DownloadProgress> downloadTiles(DownloadConfig config) async* {
    _isPaused = false;
    _isCancelled = false;

    final tilesDir = await getTilesDirectory();
    final allTiles = TileCalculator.getAllTiles(
      config.boundingBox,
      config.minZoom,
      config.maxZoom,
    );

    int downloaded = 0;
    int failed = 0;
    final total = allTiles.length;

    yield DownloadProgress(
      totalTiles: total,
      downloadedTiles: 0,
      status: DownloadStatus.downloading,
    );

    // Process tiles in batches
    for (int i = 0; i < allTiles.length; i += config.batchSize) {
      if (_isCancelled) {
        yield DownloadProgress(
          totalTiles: total,
          downloadedTiles: downloaded,
          failedTiles: failed,
          status: DownloadStatus.idle,
        );
        return;
      }

      // Handle pause
      while (_isPaused && !_isCancelled) {
        yield DownloadProgress(
          totalTiles: total,
          downloadedTiles: downloaded,
          failedTiles: failed,
          status: DownloadStatus.paused,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final batchEnd = (i + config.batchSize).clamp(0, allTiles.length);
      final batch = allTiles.sublist(i, batchEnd);

      // Download batch concurrently
      final results = await Future.wait(
        batch.map((tile) => downloadTile(
              tile,
              tilesDir,
              retryCount: config.retryCount,
              retryDelay: config.retryDelay,
            )),
      );

      for (final success in results) {
        if (success) {
          downloaded++;
        } else {
          failed++;
        }
      }

      yield DownloadProgress(
        totalTiles: total,
        downloadedTiles: downloaded,
        failedTiles: failed,
        currentZoom: batch.isNotEmpty ? batch.last.z : 0,
        status: DownloadStatus.downloading,
      );
    }

    yield DownloadProgress(
      totalTiles: total,
      downloadedTiles: downloaded,
      failedTiles: failed,
      status: DownloadStatus.completed,
    );
  }

  /// Pause the download
  void pause() {
    _isPaused = true;
  }

  /// Resume the download
  void resume() {
    _isPaused = false;
  }

  /// Cancel the download
  void cancel() {
    _isCancelled = true;
  }

  /// Check if download is paused
  bool get isPaused => _isPaused;

  /// Clean up tiles directory
  Future<void> cleanTilesDirectory() async {
    final tilesDir = await getTilesDirectory();
    if (await tilesDir.exists()) {
      await tilesDir.delete(recursive: true);
      await tilesDir.create(recursive: true);
    }
  }

  void dispose() {
    _client.close();
  }
}
