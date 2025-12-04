import 'dart:math' as math;
import '../models/models.dart';

/// Utility class for map tile calculations
class TileCalculator {
  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Convert longitude to tile X coordinate
  static int lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  /// Convert latitude to tile Y coordinate
  static int latToTileY(double lat, int zoom) {
    final latRad = lat * math.pi / 180.0;
    final n = 1 << zoom;
    return ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            n)
        .floor();
  }

  /// Get all tile coordinates within a bounding box for a specific zoom level
  static List<TileCoordinate> getTilesForZoom(BoundingBox bbox, int zoom) {
    final minX = lonToTileX(bbox.west, zoom);
    final maxX = lonToTileX(bbox.east, zoom);
    final minY = latToTileY(bbox.north, zoom);
    final maxY = latToTileY(bbox.south, zoom);

    final tiles = <TileCoordinate>[];
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        tiles.add(TileCoordinate(x: x, y: y, z: zoom));
      }
    }
    return tiles;
  }

  /// Get all tile coordinates within a bounding box for a zoom range
  static List<TileCoordinate> getAllTiles(
    BoundingBox bbox,
    int minZoom,
    int maxZoom,
  ) {
    final tiles = <TileCoordinate>[];
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      tiles.addAll(getTilesForZoom(bbox, zoom));
    }
    return tiles;
  }

  /// Calculate total tile count for a bounding box and zoom range
  static int calculateTileCount(BoundingBox bbox, int minZoom, int maxZoom) {
    int count = 0;
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      count += getTilesForZoom(bbox, zoom).length;
    }
    return count;
  }

  /// Estimate storage size in bytes (approx 15KB per tile on average)
  static int estimateStorageSize(int tileCount) {
    return tileCount * 15 * 1024; // 15 KB per tile average
  }

  /// Format bytes to human readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get tile URL for a coordinate
  static String getTileUrl(TileCoordinate tile) {
    return tileUrlTemplate
        .replaceAll('{z}', tile.z.toString())
        .replaceAll('{x}', tile.x.toString())
        .replaceAll('{y}', tile.y.toString());
  }
}
