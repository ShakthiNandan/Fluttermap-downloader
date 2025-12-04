import 'package:flutter/material.dart';
import '../models/models.dart';

/// Widget displaying download progress with controls
class DownloadProgressWidget extends StatelessWidget {
  final DownloadProgress progress;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  const DownloadProgressWidget({
    super.key,
    required this.progress,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Download Progress',
                  style: theme.textTheme.titleMedium,
                ),
                _buildStatusChip(theme),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress.hasError
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.downloadedTiles} / ${progress.totalTiles} tiles',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '${(progress.progress * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (progress.failedTiles > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Failed: ${progress.failedTiles} tiles',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (progress.currentZoom > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Current zoom level: ${progress.currentZoom}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (progress.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  progress.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildControlButtons(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme) {
    Color chipColor;
    String label;

    switch (progress.status) {
      case DownloadStatus.idle:
        chipColor = theme.colorScheme.outline;
        label = 'Idle';
        break;
      case DownloadStatus.downloading:
        chipColor = theme.colorScheme.primary;
        label = 'Downloading';
        break;
      case DownloadStatus.paused:
        chipColor = theme.colorScheme.tertiary;
        label = 'Paused';
        break;
      case DownloadStatus.completed:
        chipColor = Colors.green;
        label = 'Completed';
        break;
      case DownloadStatus.error:
        chipColor = theme.colorScheme.error;
        label = 'Error';
        break;
    }

    // Determine appropriate text color based on chip background
    final textColor = chipColor == theme.colorScheme.outline
        ? theme.colorScheme.onSurface
        : Colors.white;

    return Chip(
      label: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 12),
      ),
      backgroundColor: chipColor,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildControlButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (progress.isRunning && onPause != null)
          FilledButton.icon(
            onPressed: onPause,
            icon: const Icon(Icons.pause),
            label: const Text('Pause'),
          ),
        if (progress.isPaused && onResume != null)
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
          ),
        if ((progress.isRunning || progress.isPaused) && onCancel != null) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.stop),
            label: const Text('Cancel'),
          ),
        ],
      ],
    );
  }
}
