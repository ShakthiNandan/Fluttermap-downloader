import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/tile_calculator.dart';

/// Widget displaying tile estimation info
class TileEstimationCard extends StatelessWidget {
  final BoundingBox? boundingBox;
  final int minZoom;
  final int maxZoom;

  const TileEstimationCard({
    super.key,
    required this.boundingBox,
    required this.minZoom,
    required this.maxZoom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (boundingBox == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tile Estimation',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Long-press and drag on the map to select an area',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tileCount = TileCalculator.calculateTileCount(
      boundingBox!,
      minZoom,
      maxZoom,
    );
    final estimatedSize = TileCalculator.estimateStorageSize(tileCount);
    final formattedSize = TileCalculator.formatBytes(estimatedSize);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tile Estimation',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              Icons.grid_view,
              'Total Tiles',
              tileCount.toString(),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              Icons.storage,
              'Estimated Size',
              formattedSize,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              Icons.zoom_in,
              'Zoom Range',
              '$minZoom - $maxZoom',
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Selected Area',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'N: ${boundingBox!.north.toStringAsFixed(4)}°  '
              'S: ${boundingBox!.south.toStringAsFixed(4)}°',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'E: ${boundingBox!.east.toStringAsFixed(4)}°  '
              'W: ${boundingBox!.west.toStringAsFixed(4)}°',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
