import 'package:flutter/material.dart';
import '../models/models.dart';

/// Widget to display the multi-zoom download task queue with controls
class ZoomTaskQueueWidget extends StatelessWidget {
  final MultiZoomDownloadProgress progress;
  final VoidCallback? onStartNext;
  final VoidCallback? onSkipCurrent;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final bool isWaitingForConfirmation;

  const ZoomTaskQueueWidget({
    super.key,
    required this.progress,
    this.onStartNext,
    this.onSkipCurrent,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.isWaitingForConfirmation = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTask = progress.currentTask;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with overall progress
            Row(
              children: [
                Icon(Icons.layers, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Download Tasks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${progress.completedTaskCount}/${progress.tasks.length} completed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Overall progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall: ${progress.downloadedTiles}/${progress.totalTiles} tiles',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '${(progress.overallProgress * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress.overallProgress,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Task list
            ...progress.tasks.asMap().entries.map((entry) {
              final index = entry.key;
              final task = entry.value;
              final isCurrent = index == progress.currentTaskIndex;
              return _buildTaskItem(context, task, isCurrent);
            }),

            // Controls
            if (currentTask != null) ...[
              const SizedBox(height: 16),
              _buildControls(context, currentTask),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, ZoomLevelTask task, bool isCurrent) {
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (task.status) {
      case ZoomTaskStatus.pending:
        statusColor = theme.colorScheme.outline;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Pending';
        break;
      case ZoomTaskStatus.ready:
        statusColor = theme.colorScheme.tertiary;
        statusIcon = Icons.play_circle_outline;
        statusText = 'Ready';
        break;
      case ZoomTaskStatus.downloading:
        statusColor = theme.colorScheme.primary;
        statusIcon = Icons.downloading;
        statusText = 'Downloading';
        break;
      case ZoomTaskStatus.paused:
        statusColor = theme.colorScheme.secondary;
        statusIcon = Icons.pause_circle_outline;
        statusText = 'Paused';
        break;
      case ZoomTaskStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case ZoomTaskStatus.failed:
        statusColor = theme.colorScheme.error;
        statusIcon = Icons.error;
        statusText = 'Failed';
        break;
      case ZoomTaskStatus.skipped:
        statusColor = theme.colorScheme.outline;
        statusIcon = Icons.skip_next;
        statusText = 'Skipped';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: isCurrent
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (task.isSplit)
                      Text(
                        '${task.totalTiles} tiles in this part',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${task.downloadedTiles}/${task.totalTiles} tiles',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (task.failedTiles > 0)
                Text(
                  '${task.failedTiles} failed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
          if (task.isDownloading || task.isPaused) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, ZoomLevelTask currentTask) {
    final theme = Theme.of(context);

    // Waiting for confirmation - show Start/Skip buttons
    if (isWaitingForConfirmation && currentTask.isReady) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ready to download Zoom Level ${currentTask.zoomLevel}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStartNext,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSkipCurrent,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                onPressed: onCancel,
                icon: const Icon(Icons.close),
                tooltip: 'Cancel All',
              ),
            ],
          ),
        ],
      );
    }

    // Downloading or paused - show Pause/Resume/Cancel buttons
    if (currentTask.isDownloading || currentTask.isPaused) {
      return Row(
        children: [
          if (currentTask.isDownloading)
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onPause,
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              ),
            )
          else
            Expanded(
              child: FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
