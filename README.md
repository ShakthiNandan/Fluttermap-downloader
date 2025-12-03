# Offline Map Tiles Downloader

A Flutter application for downloading and viewing offline map tiles using flutter_map with OpenStreetMap tiles.

## Features

- **Interactive Map View**: Display OSM tiles with proper attribution
- **Bounding Box Selection**: Long-press and drag to select an area on the map
- **Zoom Level Configuration**: Pick min/max zoom levels for download
- **Tile Count Estimation**: See estimated tile count and storage size before downloading
- **Batch Downloading**: Configurable batch size for concurrent downloads
- **Pause/Resume/Cancel**: Full control over the download process
- **Retry Logic**: Automatic retry for failed tile downloads
- **ZIP Export**: Export downloaded tiles to `offline_tiles.zip`
- **ZIP Integrity Check**: Verify ZIP file integrity before use
- **Offline Viewing**: Load and display offline tiles from ZIP file
- **Material 3 Design**: Modern Material Design 3 UI
- **Dark/Light Theme**: Supports system theme preference

## Screenshots

The application consists of two main screens:

1. **Map Download Screen**: Select area, configure settings, and download tiles
2. **Offline Map Screen**: View downloaded tiles offline

## Architecture

```
lib/
├── main.dart                    # App entry point
└── src/
    ├── models/                  # Data models
    │   ├── bounding_box.dart    # Geographic bounding box
    │   ├── download_task.dart   # Download configuration and progress
    │   └── tile_coordinate.dart # Map tile coordinates
    ├── providers/               # Custom providers
    │   └── offline_tile_provider.dart # Load tiles from local storage
    ├── screens/                 # UI screens
    │   ├── map_download_screen.dart   # Main download screen
    │   └── offline_map_screen.dart    # Offline viewing screen
    ├── services/                # Business logic services
    │   ├── tile_download_service.dart # Tile downloading with batching
    │   └── zip_export_service.dart    # ZIP creation and verification
    ├── utils/                   # Utility functions
    │   └── tile_calculator.dart # Tile coordinate calculations
    └── widgets/                 # Reusable widgets
        ├── batch_config_card.dart
        ├── bounding_box_selector.dart
        ├── download_progress_widget.dart
        ├── tile_estimation_card.dart
        └── zoom_range_selector.dart
```

## Getting Started

### Prerequisites

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

### Installation

1. Clone the repository:
```bash
git clone https://github.com/ShakthiNandan/Fluttermap-downloader.git
cd Fluttermap-downloader
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
flutter run
```

## Usage

### Downloading Tiles

1. Open the app to see the map view
2. Long-press and drag on the map to select an area (bounding box)
3. Use the zoom level sliders to set min/max zoom levels
4. Configure batch size and retry count if needed
5. Review tile count and estimated storage size
6. Tap "Download Tiles" to start downloading
7. Use pause/resume/cancel controls as needed
8. When complete, tap "Export ZIP" to create `offline_tiles.zip`

### Viewing Offline

1. After exporting tiles, tap the map icon in the app bar
2. The app will verify the ZIP file integrity
3. View the offline map (tiles display based on zoom levels downloaded)

## Dependencies

- `flutter_map`: ^6.1.0 - Map widget
- `latlong2`: ^0.9.0 - Geographic coordinates
- `http`: ^1.1.0 - HTTP client for downloading tiles
- `path_provider`: ^2.1.1 - Local storage paths
- `archive`: ^3.4.9 - ZIP file handling
- `provider`: ^6.1.1 - State management
- `shared_preferences`: ^2.2.2 - Local settings storage

## Tile Storage

Downloaded tiles are stored in the app's documents directory:
```
<app_documents>/tiles/{z}/{x}/{y}.png
```

Exported ZIP file location:
```
<app_documents>/offline_tiles.zip
```

Extracted offline tiles (for viewing):
```
<app_documents>/offline_tiles/{z}/{x}/{y}.png
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| Batch Size | 10 | Number of tiles downloaded concurrently |
| Retry Count | 3 | Number of retry attempts for failed downloads |
| Min Zoom | 10 | Minimum zoom level to download |
| Max Zoom | 14 | Maximum zoom level to download |

## Attribution

This application uses map tiles from [OpenStreetMap](https://www.openstreetmap.org/):
- Tile URL: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- © OpenStreetMap contributors

## License

This project is open source. See the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.