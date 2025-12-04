import 'package:flutter/material.dart';

/// Widget for configuring batch download settings
class BatchConfigCard extends StatelessWidget {
  final int batchSize;
  final int retryCount;
  final void Function(int batchSize, int retryCount) onConfigChanged;

  const BatchConfigCard({
    super.key,
    required this.batchSize,
    required this.retryCount,
    required this.onConfigChanged,
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
            Text(
              'Download Settings',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batch Size: $batchSize',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Slider(
                        value: batchSize.toDouble(),
                        min: 1,
                        max: 50,
                        divisions: 49,
                        label: batchSize.toString(),
                        onChanged: (value) {
                          onConfigChanged(value.round(), retryCount);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Retry Count: $retryCount',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Slider(
                        value: retryCount.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: retryCount.toString(),
                        onChanged: (value) {
                          onConfigChanged(batchSize, value.round());
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Batch size controls how many tiles download concurrently. '
              'Retry count is how many times to retry failed downloads.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
