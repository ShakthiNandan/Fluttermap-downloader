import 'package:latlong2/latlong.dart';
import 'package:offline_map_tiles_downloader/src/models/models.dart';
import 'package:offline_map_tiles_downloader/src/utils/tile_calculator.dart';

void main() {
  // Test BoundingBox model
  testBoundingBox();
  
  // Test TileCoordinate model
  testTileCoordinate();
  
  // Test TileCalculator utility
  testTileCalculator();
  
  // Test DownloadProgress model
  testDownloadProgress();
  
  print('All tests passed!');
}

void testBoundingBox() {
  print('Testing BoundingBox...');
  
  // Test valid bounding box
  final bbox = BoundingBox(
    northEast: const LatLng(51.6, 0.1),
    southWest: const LatLng(51.4, -0.3),
  );
  
  assert(bbox.north == 51.6, 'North should be 51.6');
  assert(bbox.south == 51.4, 'South should be 51.4');
  assert(bbox.east == 0.1, 'East should be 0.1');
  assert(bbox.west == -0.3, 'West should be -0.3');
  assert(bbox.isValid, 'Bounding box should be valid');
  
  // Test JSON serialization
  final json = bbox.toJson();
  final restored = BoundingBox.fromJson(json);
  assert(restored.north == bbox.north, 'Restored north should match');
  assert(restored.south == bbox.south, 'Restored south should match');
  
  print('  BoundingBox tests passed!');
}

void testTileCoordinate() {
  print('Testing TileCoordinate...');
  
  final tile = TileCoordinate(x: 512, y: 340, z: 10);
  
  assert(tile.x == 512, 'X should be 512');
  assert(tile.y == 340, 'Y should be 340');
  assert(tile.z == 10, 'Z should be 10');
  assert(tile.path == '10/512/340.png', 'Path should be 10/512/340.png');
  
  // Test equality
  final tile2 = TileCoordinate(x: 512, y: 340, z: 10);
  assert(tile == tile2, 'Same coordinates should be equal');
  
  final tile3 = TileCoordinate(x: 513, y: 340, z: 10);
  assert(tile != tile3, 'Different coordinates should not be equal');
  
  print('  TileCoordinate tests passed!');
}

void testTileCalculator() {
  print('Testing TileCalculator...');
  
  // Test longitude to tile X conversion
  final tileX = TileCalculator.lonToTileX(0, 10);
  assert(tileX == 512, 'Tile X at lon 0, zoom 10 should be 512');
  
  // Test latitude to tile Y conversion
  final tileY = TileCalculator.latToTileY(0, 10);
  assert(tileY == 512, 'Tile Y at lat 0, zoom 10 should be 512');
  
  // Test tile count calculation
  final bbox = BoundingBox(
    northEast: const LatLng(51.6, 0.1),
    southWest: const LatLng(51.4, -0.3),
  );
  
  final tileCount = TileCalculator.calculateTileCount(bbox, 10, 10);
  assert(tileCount > 0, 'Tile count should be greater than 0');
  
  // Test tile URL generation
  final tile = TileCoordinate(x: 512, y: 340, z: 10);
  final url = TileCalculator.getTileUrl(tile);
  assert(url == 'https://tile.openstreetmap.org/10/512/340.png', 
         'URL should be correctly formatted');
  
  // Test bytes formatting
  assert(TileCalculator.formatBytes(500) == '500 B', 'Format bytes < 1KB');
  assert(TileCalculator.formatBytes(1536) == '1.5 KB', 'Format bytes in KB');
  assert(TileCalculator.formatBytes(1572864) == '1.5 MB', 'Format bytes in MB');
  
  print('  TileCalculator tests passed!');
}

void testDownloadProgress() {
  print('Testing DownloadProgress...');
  
  // Test default values
  const progress = DownloadProgress();
  assert(progress.totalTiles == 0, 'Default total should be 0');
  assert(progress.downloadedTiles == 0, 'Default downloaded should be 0');
  assert(progress.progress == 0.0, 'Default progress should be 0.0');
  assert(progress.status == DownloadStatus.idle, 'Default status should be idle');
  
  // Test progress calculation
  final progress2 = DownloadProgress(
    totalTiles: 100,
    downloadedTiles: 50,
    status: DownloadStatus.downloading,
  );
  assert(progress2.progress == 0.5, 'Progress should be 0.5');
  assert(progress2.isRunning, 'Should be running');
  
  // Test copyWith
  final progress3 = progress2.copyWith(
    downloadedTiles: 75,
    status: DownloadStatus.paused,
  );
  assert(progress3.downloadedTiles == 75, 'CopyWith should update downloaded');
  assert(progress3.isPaused, 'CopyWith should update status');
  assert(progress3.totalTiles == 100, 'CopyWith should preserve total');
  
  print('  DownloadProgress tests passed!');
}
