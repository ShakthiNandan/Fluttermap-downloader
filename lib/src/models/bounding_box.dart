import 'package:latlong2/latlong.dart';

/// Represents a bounding box for map tile selection
class BoundingBox {
  final LatLng northEast;
  final LatLng southWest;

  const BoundingBox({
    required this.northEast,
    required this.southWest,
  });

  double get north => northEast.latitude;
  double get south => southWest.latitude;
  double get east => northEast.longitude;
  double get west => southWest.longitude;

  bool get isValid =>
      north > south &&
      east > west &&
      north <= 85.0511 &&
      south >= -85.0511 &&
      east <= 180 &&
      west >= -180;

  @override
  String toString() =>
      'BoundingBox(N: ${north.toStringAsFixed(4)}, S: ${south.toStringAsFixed(4)}, E: ${east.toStringAsFixed(4)}, W: ${west.toStringAsFixed(4)})';

  Map<String, dynamic> toJson() => {
        'northEast': {'lat': northEast.latitude, 'lng': northEast.longitude},
        'southWest': {'lat': southWest.latitude, 'lng': southWest.longitude},
      };

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      northEast: LatLng(
        json['northEast']['lat'] as double,
        json['northEast']['lng'] as double,
      ),
      southWest: LatLng(
        json['southWest']['lat'] as double,
        json['southWest']['lng'] as double,
      ),
    );
  }
}
