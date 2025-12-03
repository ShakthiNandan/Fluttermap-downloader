import 'bounding_box.dart';

/// Status of a download task
enum DownloadStatus {
  idle,
  downloading,
  paused,
  completed,
  error,
}

/// Configuration for download task
class DownloadConfig {
  final BoundingBox boundingBox;
  final int minZoom;
  final int maxZoom;
  final int batchSize;
  final int retryCount;
  final Duration retryDelay;

  const DownloadConfig({
    required this.boundingBox,
    required this.minZoom,
    required this.maxZoom,
    this.batchSize = 10,
    this.retryCount = 3,
    this.retryDelay = const Duration(seconds: 2),
  });

  DownloadConfig copyWith({
    BoundingBox? boundingBox,
    int? minZoom,
    int? maxZoom,
    int? batchSize,
    int? retryCount,
    Duration? retryDelay,
  }) {
    return DownloadConfig(
      boundingBox: boundingBox ?? this.boundingBox,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      batchSize: batchSize ?? this.batchSize,
      retryCount: retryCount ?? this.retryCount,
      retryDelay: retryDelay ?? this.retryDelay,
    );
  }
}

/// Progress information for download task
class DownloadProgress {
  final int totalTiles;
  final int downloadedTiles;
  final int failedTiles;
  final int currentZoom;
  final DownloadStatus status;
  final String? errorMessage;

  const DownloadProgress({
    this.totalTiles = 0,
    this.downloadedTiles = 0,
    this.failedTiles = 0,
    this.currentZoom = 0,
    this.status = DownloadStatus.idle,
    this.errorMessage,
  });

  double get progress =>
      totalTiles > 0 ? downloadedTiles / totalTiles : 0.0;

  bool get isRunning => status == DownloadStatus.downloading;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isCompleted => status == DownloadStatus.completed;
  bool get hasError => status == DownloadStatus.error;

  DownloadProgress copyWith({
    int? totalTiles,
    int? downloadedTiles,
    int? failedTiles,
    int? currentZoom,
    DownloadStatus? status,
    String? errorMessage,
  }) {
    return DownloadProgress(
      totalTiles: totalTiles ?? this.totalTiles,
      downloadedTiles: downloadedTiles ?? this.downloadedTiles,
      failedTiles: failedTiles ?? this.failedTiles,
      currentZoom: currentZoom ?? this.currentZoom,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
