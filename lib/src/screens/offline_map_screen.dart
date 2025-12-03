import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/offline_tile_provider.dart';
import '../services/zip_export_service.dart';

/// Screen for viewing offline map tiles from a ZIP file
class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final ZipExportService _zipService = ZipExportService();
  final MapController _mapController = MapController();

  Directory? _tilesDirectory;
  bool _isLoading = true;
  String? _errorMessage;
  ZipVerificationResult? _verificationResult;

  @override
  void initState() {
    super.initState();
    _loadOfflineTiles();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineTiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final zipFile = await _zipService.getExistingZip();

      if (zipFile == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No offline tiles found. Please download tiles first.';
        });
        return;
      }

      // Verify ZIP integrity
      final verification = await _zipService.verifyZip(zipFile);
      _verificationResult = verification;

      if (!verification.isValid) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'ZIP file is invalid: ${verification.errorMessage ?? "Unknown error"}';
        });
        return;
      }

      // Extract ZIP
      final extractedDir = await _zipService.extractZip(zipFile);

      setState(() {
        _tilesDirectory = extractedDir;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading offline tiles: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOfflineTiles,
            tooltip: 'Reload offline tiles',
          ),
          if (_verificationResult != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showZipInfo(context),
              tooltip: 'ZIP info',
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading offline tiles...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back to Download'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tilesDirectory == null) {
      return Center(
        child: Text(
          'No tiles available',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(51.5, -0.09),
            initialZoom: 10,
            minZoom: 1,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              tileProvider: OfflineTileProvider(
                tilesDirectory: _tilesDirectory!,
              ),
              maxZoom: 19,
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors (Offline)',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.offline_bolt,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Offline Mode',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_verificationResult != null)
          Positioned(
            bottom: 60,
            left: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  '${_verificationResult!.totalFiles} tiles loaded',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showZipInfo(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Tiles Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              theme,
              'Total Files',
              _verificationResult!.totalFiles.toString(),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              theme,
              'Valid Files',
              _verificationResult!.validFiles.toString(),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              theme,
              'Status',
              _verificationResult!.isValid ? 'Valid' : 'Invalid',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
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
