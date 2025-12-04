import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../utils/tile_calculator.dart';

/// Service for downloading map tiles by zoom level with task-based control
/// Supports splitting large zoom levels into parts for multi-session downloads
class MultiZoomDownloadService {
  final http.Client _client;
  bool _isPaused = false;
  bool _isCancelled = false;
  bool _isWaitingForConfirmation = false;
  Completer<bool>? _confirmationCompleter;

  MultiZoomDownloadService({http.Client? client})
      : _client = client ?? http.Client();

  /// Get the tiles directory path
  Future<Directory> getTilesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tilesDir = Directory('${appDir.path}/tiles');
    if (!await tilesDir.exists()) {
      await tilesDir.create(recursive: true);
    }
    return tilesDir;
  }
  
  /// Get session file for saving/loading progress
  Future<File> _getSessionFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/download_session.json');
  }
  
  /// Save session progress for resumption
  Future<void> saveSession(MultiZoomDownloadProgress progress) async {
    final sessionFile = await _getSessionFile();
    await sessionFile.writeAsString(jsonEncode(progress.toJson()));
  }
  
  /// Load saved session if exists
  Future<MultiZoomDownloadProgress?> loadSession() async {
    try {
      final sessionFile = await _getSessionFile();
      if (await sessionFile.exists()) {
        final jsonStr = await sessionFile.readAsString();
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return MultiZoomDownloadProgress.fromJson(json);
      }
    } catch (e) {
      // Ignore errors, return null
    }
    return null;
  }
  
  /// Clear saved session
  Future<void> clearSession() async {
    final sessionFile = await _getSessionFile();
    if (await sessionFile.exists()) {
      await sessionFile.delete();
    }
  }

  /// Create zoom level tasks from download config, splitting large levels into parts
  List<ZoomLevelTask> createTasks(DownloadConfig config) {
    final tasks = <ZoomLevelTask>[];
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    for (int zoom = config.minZoom; zoom <= config.maxZoom; zoom++) {
      final tilesForZoom = TileCalculator.getTilesForZoom(config.boundingBox, zoom);
      final tileCount = tilesForZoom.length;
      
      if (tileCount > maxTilesPerPart) {
        // Split into multiple parts
        final numParts = (tileCount / maxTilesPerPart).ceil();
        
        for (int part = 1; part <= numParts; part++) {
          final startIndex = (part - 1) * maxTilesPerPart;
          final endIndex = (part * maxTilesPerPart).clamp(0, tileCount);
          final partTileCount = endIndex - startIndex;
          
          tasks.add(ZoomLevelTask(
            zoomLevel: zoom,
            totalTiles: partTileCount,
            boundingBox: config.boundingBox,
            status: ZoomTaskStatus.pending,
            partNumber: part,
            totalParts: numParts,
            startTileIndex: startIndex,
            endTileIndex: endIndex,
            sessionId: '${sessionId}_z${zoom}_p$part',
          ));
        }
      } else {
        // Single task for this zoom level
        tasks.add(ZoomLevelTask(
          zoomLevel: zoom,
          totalTiles: tileCount,
          boundingBox: config.boundingBox,
          status: ZoomTaskStatus.pending,
          partNumber: 0,
          totalParts: 0,
          startTileIndex: 0,
          endTileIndex: tileCount,
          sessionId: '${sessionId}_z$zoom',
        ));
      }
    }
    return tasks;
  }

  /// Download a single tile with retry logic
  Future<bool> _downloadTile(
    TileCoordinate tile,
    Directory tilesDir, {
    int retryCount = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    final url = TileCalculator.getTileUrl(tile);
    final tilePath = '${tilesDir.path}/${tile.path}';
    final tileFile = File(tilePath);

    final tileDir = tileFile.parent;
    if (!await tileDir.exists()) {
      await tileDir.create(recursive: true);
    }

    for (int attempt = 0; attempt < retryCount; attempt++) {
      try {
        final response = await _client.get(
          Uri.parse(url),
          headers: {'User-Agent': 'OfflineMapTilesDownloader/1.0'},
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

  /// Download tiles for all zoom levels, one level/part at a time
  /// Yields progress updates and waits for confirmation between levels if autoStart is false
  Stream<MultiZoomDownloadProgress> downloadTilesByZoom(
    DownloadConfig config, {
    bool autoStart = false,
    MultiZoomDownloadProgress? resumeFrom,
  }) async* {
    _isPaused = false;
    _isCancelled = false;
    _isWaitingForConfirmation = false;

    final tilesDir = await getTilesDirectory();
    
    // Use existing tasks if resuming, otherwise create new
    List<ZoomLevelTask> tasks;
    int startFromIndex;
    
    if (resumeFrom != null && resumeFrom.tasks.isNotEmpty) {
      tasks = resumeFrom.tasks;
      // Find first non-finished task
      startFromIndex = tasks.indexWhere((t) => !t.isFinished);
      if (startFromIndex < 0) startFromIndex = tasks.length;
    } else {
      tasks = createTasks(config);
      startFromIndex = 0;
    }

    var progress = MultiZoomDownloadProgress(
      tasks: tasks,
      currentTaskIndex: startFromIndex > 0 ? startFromIndex - 1 : -1,
      autoStart: autoStart,
    );
    yield progress;
    
    // Save initial session
    await saveSession(progress);

    for (int taskIndex = startFromIndex; taskIndex < tasks.length; taskIndex++) {
      if (_isCancelled) {
        await saveSession(progress);
        progress = progress.copyWith(isFinished: true);
        yield progress;
        return;
      }

      // Mark current task as ready and wait for confirmation if not auto-start
      progress = progress.updateTask(
        taskIndex,
        tasks[taskIndex].copyWith(status: ZoomTaskStatus.ready),
      ).copyWith(currentTaskIndex: taskIndex);
      yield progress;

      if (!autoStart && taskIndex > startFromIndex) {
        // Wait for user confirmation to proceed
        _isWaitingForConfirmation = true;
        _confirmationCompleter = Completer<bool>();
        
        await saveSession(progress);
        yield progress; // Emit so UI knows we're waiting

        final shouldProceed = await _confirmationCompleter!.future;
        _isWaitingForConfirmation = false;

        if (!shouldProceed || _isCancelled) {
          // User skipped or cancelled
          progress = progress.updateTask(
            taskIndex,
            progress.tasks[taskIndex].copyWith(status: ZoomTaskStatus.skipped),
          );
          await saveSession(progress);
          yield progress;
          continue;
        }
      }

      // Start downloading this zoom level/part
      final task = progress.tasks[taskIndex];
      final allTilesForZoom = TileCalculator.getTilesForZoom(config.boundingBox, task.zoomLevel);
      
      // Get tiles for this specific part
      final tiles = allTilesForZoom.sublist(
        task.startTileIndex, 
        task.endTileIndex.clamp(0, allTilesForZoom.length),
      );
      
      var currentTask = task.copyWith(status: ZoomTaskStatus.downloading);
      progress = progress.updateTask(taskIndex, currentTask);
      yield progress;

      int downloaded = 0;
      int failed = 0;

      // Process tiles in batches
      for (int i = 0; i < tiles.length; i += config.batchSize) {
        if (_isCancelled) {
          currentTask = currentTask.copyWith(
            status: ZoomTaskStatus.paused,
            downloadedTiles: downloaded,
            failedTiles: failed,
          );
          progress = progress.updateTask(taskIndex, currentTask);
          await saveSession(progress);
          progress = progress.copyWith(isFinished: true);
          yield progress;
          return;
        }

        // Handle pause
        while (_isPaused && !_isCancelled) {
          currentTask = currentTask.copyWith(
            status: ZoomTaskStatus.paused,
            downloadedTiles: downloaded,
            failedTiles: failed,
          );
          progress = progress.updateTask(taskIndex, currentTask);
          await saveSession(progress);
          yield progress;
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (!_isPaused) {
          currentTask = currentTask.copyWith(status: ZoomTaskStatus.downloading);
        }

        final batchEnd = (i + config.batchSize).clamp(0, tiles.length);
        final batch = tiles.sublist(i, batchEnd);

        final results = await Future.wait(
          batch.map((tile) => _downloadTile(
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

        currentTask = currentTask.copyWith(
          downloadedTiles: downloaded,
          failedTiles: failed,
        );
        progress = progress.updateTask(taskIndex, currentTask);
        
        // Save session every 10 batches for resume support
        if ((i ~/ config.batchSize) % 10 == 0) {
          await saveSession(progress);
        }
        
        yield progress;
      }

      // Mark task as completed
      currentTask = currentTask.copyWith(status: ZoomTaskStatus.completed);
      progress = progress.updateTask(taskIndex, currentTask);
      await saveSession(progress);
      yield progress;
    }

    // All tasks finished
    progress = progress.copyWith(isFinished: true);
    await clearSession(); // Clear session when fully complete
    yield progress;
  }

  /// Confirm and start the next pending task
  void confirmNextTask() {
    if (_isWaitingForConfirmation && _confirmationCompleter != null) {
      _confirmationCompleter!.complete(true);
    }
  }

  /// Skip the current pending task
  void skipCurrentTask() {
    if (_isWaitingForConfirmation && _confirmationCompleter != null) {
      _confirmationCompleter!.complete(false);
    }
  }

  /// Pause the download
  void pause() {
    _isPaused = true;
  }

  /// Resume the download
  void resume() {
    _isPaused = false;
  }

  /// Cancel the entire download operation
  void cancel() {
    _isCancelled = true;
    if (_isWaitingForConfirmation && _confirmationCompleter != null) {
      _confirmationCompleter!.complete(false);
    }
  }

  bool get isPaused => _isPaused;
  bool get isWaitingForConfirmation => _isWaitingForConfirmation;

  /// Clean up tiles directory
  Future<void> cleanTilesDirectory() async {
    final tilesDir = await getTilesDirectory();
    if (await tilesDir.exists()) {
      await tilesDir.delete(recursive: true);
      await tilesDir.create(recursive: true);
    }
  }

  void dispose() {
    _isCancelled = true;
    if (_confirmationCompleter != null && !_confirmationCompleter!.isCompleted) {
      _confirmationCompleter!.complete(false);
    }
    _client.close();
  }
}
