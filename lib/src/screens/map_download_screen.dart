import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';

/// Main screen for downloading map tiles
class MapDownloadScreen extends StatefulWidget {
  const MapDownloadScreen({super.key});

  @override
  State<MapDownloadScreen> createState() => _MapDownloadScreenState();
}

class _MapDownloadScreenState extends State<MapDownloadScreen> {
  final MapController _mapController = MapController();
  final GlobalKey<_BoundingBoxSelectorState> _bboxSelectorKey =
      GlobalKey<_BoundingBoxSelectorState>();
  final TileDownloadService _downloadService = TileDownloadService();
  final ZipExportService _zipService = ZipExportService();

  BoundingBox? _selectedBoundingBox;
  int _minZoom = 10;
  int _maxZoom = 14;
  int _batchSize = 10;
  int _retryCount = 3;
  DownloadProgress _downloadProgress = const DownloadProgress();
  StreamSubscription<DownloadProgress>? _downloadSubscription;
  bool _isExporting = false;

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    _downloadService.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onBoundingBoxChanged(BoundingBox? bbox) {
    setState(() {
      _selectedBoundingBox = bbox;
    });
  }

  void _onZoomRangeChanged(int min, int max) {
    setState(() {
      _minZoom = min;
      _maxZoom = max;
    });
  }

  void _onConfigChanged(int batchSize, int retryCount) {
    setState(() {
      _batchSize = batchSize;
      _retryCount = retryCount;
    });
  }

  void _clearSelection() {
    _bboxSelectorKey.currentState?.clearSelection();
    setState(() {
      _selectedBoundingBox = null;
      _downloadProgress = const DownloadProgress();
    });
  }

  Future<void> _startDownload() async {
    if (_selectedBoundingBox == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an area on the map first'),
        ),
      );
      return;
    }

    final config = DownloadConfig(
      boundingBox: _selectedBoundingBox!,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
      batchSize: _batchSize,
      retryCount: _retryCount,
    );

    _downloadSubscription?.cancel();
    _downloadSubscription = _downloadService.downloadTiles(config).listen(
      (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
      onError: (error) {
        setState(() {
          _downloadProgress = _downloadProgress.copyWith(
            status: DownloadStatus.error,
            errorMessage: error.toString(),
          );
        });
      },
    );
  }

  void _pauseDownload() {
    _downloadService.pause();
  }

  void _resumeDownload() {
    _downloadService.resume();
  }

  void _cancelDownload() {
    _downloadService.cancel();
    _downloadSubscription?.cancel();
    setState(() {
      _downloadProgress = const DownloadProgress();
    });
  }

  Future<void> _exportToZip() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final zipFile = await _zipService.exportToZip();
      final verification = await _zipService.verifyZip(zipFile);

      if (!mounted) return;

      if (verification.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${verification.totalFiles} tiles to offline_tiles.zip',
            ),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: ${verification.errorMessage ?? "Unknown error"}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _cleanTilesFolder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Tiles Folder'),
        content: const Text(
          'This will delete all downloaded tiles. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _downloadService.cleanTilesDirectory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tiles folder cleaned')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Map Tiles Downloader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _cleanTilesFolder,
            tooltip: 'Clean tiles folder',
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () => Navigator.of(context).pushNamed('/offline'),
            tooltip: 'View offline map',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(51.5, -0.09),
                    initialZoom: 10,
                    minZoom: 1,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.offline_map_downloader',
                      maxZoom: 19,
                    ),
                    _BoundingBoxSelector(
                      key: _bboxSelectorKey,
                      mapController: _mapController,
                      onBoundingBoxChanged: _onBoundingBoxChanged,
                    ),
                    RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'Long-press to select area',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
                if (_selectedBoundingBox != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: FilledButton.icon(
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TileEstimationCard(
                    boundingBox: _selectedBoundingBox,
                    minZoom: _minZoom,
                    maxZoom: _maxZoom,
                  ),
                  const SizedBox(height: 8),
                  ZoomRangeSelector(
                    minZoom: _minZoom,
                    maxZoom: _maxZoom,
                    onZoomRangeChanged: _onZoomRangeChanged,
                  ),
                  const SizedBox(height: 8),
                  BatchConfigCard(
                    batchSize: _batchSize,
                    retryCount: _retryCount,
                    onConfigChanged: _onConfigChanged,
                  ),
                  const SizedBox(height: 8),
                  if (_downloadProgress.status != DownloadStatus.idle)
                    DownloadProgressWidget(
                      progress: _downloadProgress,
                      onPause: _pauseDownload,
                      onResume: _resumeDownload,
                      onCancel: _cancelDownload,
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_downloadProgress.isRunning ||
                                  _downloadProgress.isPaused)
                              ? null
                              : _startDownload,
                          icon: const Icon(Icons.download),
                          label: const Text('Download Tiles'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: (_downloadProgress.isCompleted &&
                                  !_isExporting)
                              ? _exportToZip
                              : null,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.archive),
                          label: const Text('Export ZIP'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal bounding box selector widget
class _BoundingBoxSelector extends StatefulWidget {
  final MapController mapController;
  final void Function(BoundingBox? bbox) onBoundingBoxChanged;

  const _BoundingBoxSelector({
    super.key,
    required this.mapController,
    required this.onBoundingBoxChanged,
  });

  @override
  State<_BoundingBoxSelector> createState() => _BoundingBoxSelectorState();
}

class _BoundingBoxSelectorState extends State<_BoundingBoxSelector> {
  LatLng? _startPoint;
  LatLng? _currentPoint;
  bool _isDragging = false;

  BoundingBox? get _currentBoundingBox {
    if (_startPoint == null || _currentPoint == null) return null;

    final north = _startPoint!.latitude > _currentPoint!.latitude
        ? _startPoint!.latitude
        : _currentPoint!.latitude;
    final south = _startPoint!.latitude <= _currentPoint!.latitude
        ? _startPoint!.latitude
        : _currentPoint!.latitude;
    final east = _startPoint!.longitude > _currentPoint!.longitude
        ? _startPoint!.longitude
        : _currentPoint!.longitude;
    final west = _startPoint!.longitude <= _currentPoint!.longitude
        ? _startPoint!.longitude
        : _currentPoint!.longitude;

    return BoundingBox(
      northEast: LatLng(north, east),
      southWest: LatLng(south, west),
    );
  }

  List<LatLng> get _boundingBoxPolygon {
    final bbox = _currentBoundingBox;
    if (bbox == null) return [];

    return [
      LatLng(bbox.north, bbox.west),
      LatLng(bbox.north, bbox.east),
      LatLng(bbox.south, bbox.east),
      LatLng(bbox.south, bbox.west),
    ];
  }

  void clearSelection() {
    setState(() {
      _startPoint = null;
      _currentPoint = null;
      _isDragging = false;
    });
    widget.onBoundingBoxChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final polygon = _boundingBoxPolygon;

    return Stack(
      children: [
        if (polygon.isNotEmpty)
          PolygonLayer(
            polygons: [
              Polygon(
                points: polygon,
                color: theme.colorScheme.primary.withOpacity(0.2),
                borderColor: theme.colorScheme.primary,
                borderStrokeWidth: 2,
                isFilled: true,
              ),
            ],
          ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: (details) {
            final point = widget.mapController.camera.pointToLatLng(
              Point(details.localPosition.dx, details.localPosition.dy),
            );
            setState(() {
              _startPoint = point;
              _currentPoint = point;
              _isDragging = true;
            });
          },
          onLongPressMoveUpdate: (details) {
            if (_isDragging) {
              final point = widget.mapController.camera.pointToLatLng(
                Point(details.localPosition.dx, details.localPosition.dy),
              );
              setState(() {
                _currentPoint = point;
              });
            }
          },
          onLongPressEnd: (details) {
            if (_isDragging) {
              final point = widget.mapController.camera.pointToLatLng(
                Point(details.localPosition.dx, details.localPosition.dy),
              );
              setState(() {
                _currentPoint = point;
                _isDragging = false;
              });
              widget.onBoundingBoxChanged(_currentBoundingBox);
            }
          },
        ),
      ],
    );
  }
}
