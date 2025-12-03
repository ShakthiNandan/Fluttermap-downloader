/// Represents a single map tile coordinate
class TileCoordinate {
  final int x;
  final int y;
  final int z;

  const TileCoordinate({
    required this.x,
    required this.y,
    required this.z,
  });

  String get path => '$z/$x/$y.png';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileCoordinate &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          z == other.z;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ z.hashCode;

  @override
  String toString() => 'TileCoordinate(z: $z, x: $x, y: $y)';
}
