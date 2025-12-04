import 'dart:async';
import 'dart:io';
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
  final GlobalKey<BoundingBoxSelectorState> _bboxSelectorKey =
      GlobalKey<BoundingBoxSelectorState>();
  final MultiZoomDownloadService _downloadService = MultiZoomDownloadService();
  final ZipExportService _zipService = ZipExportService();

  BoundingBox? _selectedBoundingBox;
  int _minZoom = 10;
  int _maxZoom = 14;
  int _batchSize = 10;
  int _retryCount = 3;
  bool _autoStartTasks = false;  // Whether to auto-start next zoom level
  MultiZoomDownloadProgress _downloadProgress = const MultiZoomDownloadProgress();
  StreamSubscription<MultiZoomDownloadProgress>? _downloadSubscription;
  bool _isExporting = false;
  bool _isDownloading = false;
  bool _hasSavedSession = false;
  List<File> _availableZipFiles = [];

  @override
  void initState() {
    super.initState();
    _checkForSavedSession();
    _loadAvailableZips();
  }

  Future<void> _checkForSavedSession() async {
    final session = await _downloadService.loadSession();
    if (mounted) {
      setState(() {
        _hasSavedSession = session != null && !session.isFinished;
      });
    }
  }

  Future<void> _loadAvailableZips() async {
    final zips = await _zipService.getPartZipFiles();
    if (mounted) {
      setState(() {
        _availableZipFiles = zips;
      });
    }
  }

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
      _downloadProgress = const MultiZoomDownloadProgress();
      _isDownloading = false;
    });
  }

  Future<void> _startDownload({MultiZoomDownloadProgress? resumeFrom}) async {
    if (_selectedBoundingBox == null && resumeFrom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an area on the map first'),
        ),
      );
      return;
    }

    final bbox = resumeFrom?.tasks.firstOrNull?.boundingBox ?? _selectedBoundingBox!;
    final config = DownloadConfig(
      boundingBox: bbox,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
      batchSize: _batchSize,
      retryCount: _retryCount,
    );

    setState(() {
      _isDownloading = true;
      _hasSavedSession = false;
    });

    _downloadSubscription?.cancel();
    _downloadSubscription = _downloadService
        .downloadTilesByZoom(config, autoStart: _autoStartTasks, resumeFrom: resumeFrom)
        .listen(
      (progress) {
        setState(() {
          _downloadProgress = progress;
          if (progress.isFinished) {
            _isDownloading = false;
            _loadAvailableZips();
          }
        });
      },
      onError: (error) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
      onDone: () {
        setState(() {
          _isDownloading = false;
        });
        _loadAvailableZips();
      },
    );
  }

  Future<void> _resumeSession() async {
    final session = await _downloadService.loadSession();
    if (session != null) {
      // Set bounding box from session
      if (session.tasks.isNotEmpty) {
        setState(() {
          _selectedBoundingBox = session.tasks.first.boundingBox;
        });
      }
      await _startDownload(resumeFrom: session);
    }
  }

  Future<void> _clearSavedSession() async {
    await _downloadService.clearSession();
    setState(() {
      _hasSavedSession = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved session cleared')),
      );
    }
  }

  void _confirmNextTask() {
    _downloadService.confirmNextTask();
  }

  void _skipCurrentTask() {
    _downloadService.skipCurrentTask();
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
      _downloadProgress = const MultiZoomDownloadProgress();
      _isDownloading = false;
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
        await _loadAvailableZips();
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

  Future<void> _showMergeZipsDialog() async {
    if (_availableZipFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ZIP files available to merge')),
      );
      return;
    }

    final selectedFiles = <File>[];
    
    final result = await showDialog<List<File>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Merge ZIP Files'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select ZIP files to merge into a final archive:'),
                const SizedBox(height: 12),
                ...List.generate(_availableZipFiles.length, (index) {
                  final file = _availableZipFiles[index];
                  final fileName = file.path.split(Platform.pathSeparator).last;
                  final isSelected = selectedFiles.contains(file);
                  
                  return CheckboxListTile(
                    title: Text(fileName, style: const TextStyle(fontSize: 14)),
                    value: isSelected,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedFiles.add(file);
                        } else {
                          selectedFiles.remove(file);
                        }
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedFiles.length >= 2
                  ? () => Navigator.of(context).pop(selectedFiles)
                  : null,
              child: const Text('Merge'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.length >= 2) {
      await _mergeZipFiles(result);
    }
  }

  Future<void> _mergeZipFiles(List<File> files) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final mergedFile = await _zipService.mergeZipFiles(files);
      final verification = await _zipService.verifyZip(mergedFile);

      if (!mounted) return;

      if (verification.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Merged ${verification.totalFiles} tiles into ${mergedFile.path.split(Platform.pathSeparator).last}',
            ),
          ),
        );
        await _loadAvailableZips();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merge failed: ${verification.errorMessage ?? "Unknown error"}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Merge error: $e'),
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
                    BoundingBoxSelector(
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
                  // Auto-start toggle card
                  Card(
                    child: SwitchListTile(
                      title: const Text('Auto-start next zoom level'),
                      subtitle: Text(
                        _autoStartTasks
                            ? 'Tasks will run continuously'
                            : 'Wait for confirmation between zoom levels',
                        style: theme.textTheme.bodySmall,
                      ),
                      value: _autoStartTasks,
                      onChanged: _isDownloading
                          ? null
                          : (value) {
                              setState(() {
                                _autoStartTasks = value;
                              });
                            },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Resume session card
                  if (_hasSavedSession && !_isDownloading)
                    Card(
                      color: theme.colorScheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.restore, color: theme.colorScheme.tertiary),
                                const SizedBox(width: 8),
                                Text(
                                  'Saved Session Available',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You have an incomplete download session. Resume or clear it.',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _resumeSession,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Resume'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _clearSavedSession,
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Clear'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_hasSavedSession && !_isDownloading)
                    const SizedBox(height: 8),
                  // Show task queue when downloading
                  if (_downloadProgress.tasks.isNotEmpty)
                    ZoomTaskQueueWidget(
                      progress: _downloadProgress,
                      isWaitingForConfirmation: _downloadService.isWaitingForConfirmation,
                      onStartNext: _confirmNextTask,
                      onSkipCurrent: _skipCurrentTask,
                      onPause: _pauseDownload,
                      onResume: _resumeDownload,
                      onCancel: _cancelDownload,
                    ),
                  const SizedBox(height: 16),
                  // Download and Export buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isDownloading ? null : () => _startDownload(),
                          icon: const Icon(Icons.download),
                          label: const Text('Download Tiles'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: (_downloadProgress.isFinished &&
                                  _downloadProgress.completedTaskCount > 0 &&
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
                  // Merge ZIPs button
                  if (_availableZipFiles.length >= 2 && !_isDownloading) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isExporting ? null : _showMergeZipsDialog,
                        icon: const Icon(Icons.merge_type),
                        label: Text('Merge ${_availableZipFiles.length} ZIP Files'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
