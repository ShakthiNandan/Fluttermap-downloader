import 'package:latlong2/latlong.dart';
import 'bounding_box.dart';

/// Maximum tiles per part before splitting
const int maxTilesPerPart = 5000;

/// Status of a zoom level download task
enum ZoomTaskStatus {
  pending,      // Waiting to start
  ready,        // Ready to start (awaiting user confirmation)
  downloading,  // Currently downloading
  paused,       // Paused by user
  completed,    // Successfully completed
  failed,       // Failed with errors
  skipped,      // Skipped by user
}

/// Represents a download task for a single zoom level (or part of one)
class ZoomLevelTask {
  final int zoomLevel;
  final int totalTiles;
  final BoundingBox boundingBox;
  final int downloadedTiles;
  final int failedTiles;
  final ZoomTaskStatus status;
  final String? errorMessage;
  
  // Part tracking for large zoom levels
  final int partNumber;      // 1-based part number (0 means not split)
  final int totalParts;      // Total parts for this zoom level (0 means not split)
  final int startTileIndex;  // Starting tile index for this part
  final int endTileIndex;    // Ending tile index (exclusive) for this part
  final String? sessionId;   // Unique ID for session tracking/resumption

  const ZoomLevelTask({
    required this.zoomLevel,
    required this.totalTiles,
    required this.boundingBox,
    this.downloadedTiles = 0,
    this.failedTiles = 0,
    this.status = ZoomTaskStatus.pending,
    this.errorMessage,
    this.partNumber = 0,
    this.totalParts = 0,
    this.startTileIndex = 0,
    this.endTileIndex = 0,
    this.sessionId,
  });

  /// Whether this task is part of a split zoom level
  bool get isSplit => totalParts > 1;
  
  /// Display name for the task
  String get displayName {
    if (isSplit) {
      return 'Zoom $zoomLevel (Part $partNumber/$totalParts)';
    }
    return 'Zoom Level $zoomLevel';
  }

  double get progress => totalTiles > 0 ? downloadedTiles / totalTiles : 0.0;

  bool get isPending => status == ZoomTaskStatus.pending;
  bool get isReady => status == ZoomTaskStatus.ready;
  bool get isDownloading => status == ZoomTaskStatus.downloading;
  bool get isPaused => status == ZoomTaskStatus.paused;
  bool get isCompleted => status == ZoomTaskStatus.completed;
  bool get isFailed => status == ZoomTaskStatus.failed;
  bool get isSkipped => status == ZoomTaskStatus.skipped;
  bool get isFinished => isCompleted || isFailed || isSkipped;

  ZoomLevelTask copyWith({
    int? zoomLevel,
    int? totalTiles,
    BoundingBox? boundingBox,
    int? downloadedTiles,
    int? failedTiles,
    ZoomTaskStatus? status,
    String? errorMessage,
    int? partNumber,
    int? totalParts,
    int? startTileIndex,
    int? endTileIndex,
    String? sessionId,
  }) {
    return ZoomLevelTask(
      zoomLevel: zoomLevel ?? this.zoomLevel,
      totalTiles: totalTiles ?? this.totalTiles,
      boundingBox: boundingBox ?? this.boundingBox,
      downloadedTiles: downloadedTiles ?? this.downloadedTiles,
      failedTiles: failedTiles ?? this.failedTiles,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      partNumber: partNumber ?? this.partNumber,
      totalParts: totalParts ?? this.totalParts,
      startTileIndex: startTileIndex ?? this.startTileIndex,
      endTileIndex: endTileIndex ?? this.endTileIndex,
      sessionId: sessionId ?? this.sessionId,
    );
  }
  
  /// Convert to JSON for session persistence
  Map<String, dynamic> toJson() => {
    'zoomLevel': zoomLevel,
    'totalTiles': totalTiles,
    'downloadedTiles': downloadedTiles,
    'failedTiles': failedTiles,
    'status': status.index,
    'partNumber': partNumber,
    'totalParts': totalParts,
    'startTileIndex': startTileIndex,
    'endTileIndex': endTileIndex,
    'sessionId': sessionId,
    'boundingBox': {
      'north': boundingBox.north,
      'south': boundingBox.south,
      'east': boundingBox.east,
      'west': boundingBox.west,
    },
  };
  
  /// Create from JSON for session resumption
  factory ZoomLevelTask.fromJson(Map<String, dynamic> json) {
    final bboxJson = json['boundingBox'] as Map<String, dynamic>;
    return ZoomLevelTask(
      zoomLevel: json['zoomLevel'] as int,
      totalTiles: json['totalTiles'] as int,
      downloadedTiles: json['downloadedTiles'] as int? ?? 0,
      failedTiles: json['failedTiles'] as int? ?? 0,
      status: ZoomTaskStatus.values[json['status'] as int? ?? 0],
      partNumber: json['partNumber'] as int? ?? 0,
      totalParts: json['totalParts'] as int? ?? 0,
      startTileIndex: json['startTileIndex'] as int? ?? 0,
      endTileIndex: json['endTileIndex'] as int? ?? 0,
      sessionId: json['sessionId'] as String?,
      boundingBox: BoundingBox(
        northEast: LatLng(bboxJson['north'] as double, bboxJson['east'] as double),
        southWest: LatLng(bboxJson['south'] as double, bboxJson['west'] as double),
      ),
    );
  }
}

/// Progress for the entire multi-zoom download operation
class MultiZoomDownloadProgress {
  final List<ZoomLevelTask> tasks;
  final int currentTaskIndex;
  final bool autoStart;  // Whether to auto-start next task or wait for confirmation
  final bool isFinished;

  const MultiZoomDownloadProgress({
    this.tasks = const [],
    this.currentTaskIndex = -1,
    this.autoStart = false,
    this.isFinished = false,
  });

  ZoomLevelTask? get currentTask =>
      currentTaskIndex >= 0 && currentTaskIndex < tasks.length
          ? tasks[currentTaskIndex]
          : null;

  int get totalTiles => tasks.fold(0, (sum, t) => sum + t.totalTiles);
  int get downloadedTiles => tasks.fold(0, (sum, t) => sum + t.downloadedTiles);
  int get failedTiles => tasks.fold(0, (sum, t) => sum + t.failedTiles);
  double get overallProgress => totalTiles > 0 ? downloadedTiles / totalTiles : 0.0;

  int get completedTaskCount => tasks.where((t) => t.isCompleted).length;
  int get pendingTaskCount => tasks.where((t) => t.isPending || t.isReady).length;

  bool get hasNextTask {
    for (int i = currentTaskIndex + 1; i < tasks.length; i++) {
      if (!tasks[i].isFinished) return true;
    }
    return false;
  }

  /// Get list of completed tasks that can be exported individually
  List<ZoomLevelTask> get exportableTasks => 
      tasks.where((t) => t.isCompleted).toList();

  MultiZoomDownloadProgress copyWith({
    List<ZoomLevelTask>? tasks,
    int? currentTaskIndex,
    bool? autoStart,
    bool? isFinished,
  }) {
    return MultiZoomDownloadProgress(
      tasks: tasks ?? this.tasks,
      currentTaskIndex: currentTaskIndex ?? this.currentTaskIndex,
      autoStart: autoStart ?? this.autoStart,
      isFinished: isFinished ?? this.isFinished,
    );
  }

  /// Update a specific task in the list
  MultiZoomDownloadProgress updateTask(int index, ZoomLevelTask updatedTask) {
    final newTasks = List<ZoomLevelTask>.from(tasks);
    if (index >= 0 && index < newTasks.length) {
      newTasks[index] = updatedTask;
    }
    return copyWith(tasks: newTasks);
  }
  
  /// Convert to JSON for session persistence
  Map<String, dynamic> toJson() => {
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'currentTaskIndex': currentTaskIndex,
    'autoStart': autoStart,
    'isFinished': isFinished,
  };
  
  /// Create from JSON for session resumption
  factory MultiZoomDownloadProgress.fromJson(Map<String, dynamic> json) {
    final tasksList = (json['tasks'] as List?)
        ?.map((t) => ZoomLevelTask.fromJson(t as Map<String, dynamic>))
        .toList() ?? [];
    return MultiZoomDownloadProgress(
      tasks: tasksList,
      currentTaskIndex: json['currentTaskIndex'] as int? ?? -1,
      autoStart: json['autoStart'] as bool? ?? false,
      isFinished: json['isFinished'] as bool? ?? false,
    );
  }
}
