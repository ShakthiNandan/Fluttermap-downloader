import 'package:flutter/material.dart';

/// Widget for selecting min and max zoom levels
class ZoomRangeSelector extends StatelessWidget {
  final int minZoom;
  final int maxZoom;
  final int minZoomLimit;
  final int maxZoomLimit;
  final void Function(int min, int max) onZoomRangeChanged;

  const ZoomRangeSelector({
    super.key,
    required this.minZoom,
    required this.maxZoom,
    this.minZoomLimit = 1,
    this.maxZoomLimit = 19,
    required this.onZoomRangeChanged,
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
              'Zoom Levels',
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
                        'Min Zoom: $minZoom',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Slider(
                        value: minZoom.toDouble(),
                        min: minZoomLimit.toDouble(),
                        max: (maxZoom - 1).toDouble(),
                        divisions: (maxZoom - 1 - minZoomLimit),
                        label: minZoom.toString(),
                        onChanged: (value) {
                          onZoomRangeChanged(value.round(), maxZoom);
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
                        'Max Zoom: $maxZoom',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Slider(
                        value: maxZoom.toDouble(),
                        min: (minZoom + 1).toDouble(),
                        max: maxZoomLimit.toDouble(),
                        divisions: (maxZoomLimit - minZoom - 1),
                        label: maxZoom.toString(),
                        onChanged: (value) {
                          onZoomRangeChanged(minZoom, value.round());
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
