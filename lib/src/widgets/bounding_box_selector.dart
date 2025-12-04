import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

/// Widget for selecting a bounding box on the map by dragging
class BoundingBoxSelector extends StatefulWidget {
  final MapController mapController;
  final void Function(BoundingBox? bbox) onBoundingBoxChanged;
  final BoundingBox? initialBoundingBox;

  const BoundingBoxSelector({
    super.key,
    required this.mapController,
    required this.onBoundingBoxChanged,
    this.initialBoundingBox,
  });

  @override
  BoundingBoxSelectorState createState() => BoundingBoxSelectorState();
}

/// State class made public to allow access via GlobalKey
class BoundingBoxSelectorState extends State<BoundingBoxSelector> {
  LatLng? _startPoint;
  LatLng? _currentPoint;
  bool _isDragging = false;

  BoundingBox? get _currentBoundingBox {
    if (_startPoint == null || _currentPoint == null) return null;

    final north = _startPoint!.latitude > _currentPoint!.latitude
        ? _startPoint!.latitude
        : _currentPoint!.latitude;
    final south = _startPoint!.latitude <= _currentPoint!.latitude
        ? _startPoint!.latitude
        : _currentPoint!.latitude;
    final east = _startPoint!.longitude > _currentPoint!.longitude
        ? _startPoint!.longitude
        : _currentPoint!.longitude;
    final west = _startPoint!.longitude <= _currentPoint!.longitude
        ? _startPoint!.longitude
        : _currentPoint!.longitude;

    return BoundingBox(
      northEast: LatLng(north, east),
      southWest: LatLng(south, west),
    );
  }

  List<LatLng> get _boundingBoxPolygon {
    final bbox = _currentBoundingBox;
    if (bbox == null) return [];

    return [
      LatLng(bbox.north, bbox.west),
      LatLng(bbox.north, bbox.east),
      LatLng(bbox.south, bbox.east),
      LatLng(bbox.south, bbox.west),
    ];
  }

  /// Clear the current selection
  void clearSelection() {
    setState(() {
      _startPoint = null;
      _currentPoint = null;
      _isDragging = false;
    });
    widget.onBoundingBoxChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final polygon = _boundingBoxPolygon;

    return Stack(
      children: [
        if (polygon.isNotEmpty)
          PolygonLayer(
            polygons: [
              Polygon(
                points: polygon,
                color: theme.colorScheme.primary.withOpacity(0.2),
                borderColor: theme.colorScheme.primary,
                borderStrokeWidth: 2,
                isFilled: true,
              ),
            ],
          ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: (details) {
            final point = widget.mapController.camera.pointToLatLng(
              math.Point(details.localPosition.dx, details.localPosition.dy),
            );
            setState(() {
              _startPoint = point;
              _currentPoint = point;
              _isDragging = true;
            });
          },
          onLongPressMoveUpdate: (details) {
            if (_isDragging) {
              final point = widget.mapController.camera.pointToLatLng(
                math.Point(details.localPosition.dx, details.localPosition.dy),
              );
              setState(() {
                _currentPoint = point;
              });
            }
          },
          onLongPressEnd: (details) {
            if (_isDragging) {
              final point = widget.mapController.camera.pointToLatLng(
                math.Point(details.localPosition.dx, details.localPosition.dy),
              );
              setState(() {
                _currentPoint = point;
                _isDragging = false;
              });
              widget.onBoundingBoxChanged(_currentBoundingBox);
            }
          },
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}
