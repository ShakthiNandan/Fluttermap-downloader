import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

/// Service for exporting tiles to ZIP and verifying ZIP integrity
class ZipExportService {
  /// Get list of existing part ZIP files
  Future<List<File>> getPartZipFiles() async {
    final appDir = await getApplicationDocumentsDirectory();
    final files = <File>[];
    
    await for (final entity in Directory(appDir.path).list()) {
      if (entity is File && entity.path.endsWith('.zip')) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('tiles_') || name == 'offline_tiles.zip') {
          files.add(entity);
        }
      }
    }
    
    // Sort by name
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// Export tiles directory to a ZIP file
  Future<File> exportToZip({String fileName = 'offline_tiles.zip'}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final tilesDir = Directory('${appDir.path}/tiles');
    final zipPath = '${appDir.path}/$fileName';

    if (!await tilesDir.exists()) {
      throw Exception('Tiles directory does not exist');
    }

    final archive = Archive();
    await _addDirectoryToArchive(archive, tilesDir, tilesDir.path);

    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    if (zipData == null) {
      throw Exception('Failed to create ZIP archive');
    }

    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(zipData);

    return zipFile;
  }
  
  /// Export tiles for a specific zoom level to a ZIP file
  Future<File> exportZoomLevelToZip(int zoomLevel, {int? partNumber}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final tilesDir = Directory('${appDir.path}/tiles/$zoomLevel');
    
    String fileName;
    if (partNumber != null && partNumber > 0) {
      fileName = 'tiles_zoom${zoomLevel}_part$partNumber.zip';
    } else {
      fileName = 'tiles_zoom$zoomLevel.zip';
    }
    final zipPath = '${appDir.path}/$fileName';

    if (!await tilesDir.exists()) {
      throw Exception('Tiles directory for zoom level $zoomLevel does not exist');
    }

    final archive = Archive();
    await _addDirectoryToArchive(archive, tilesDir, Directory('${appDir.path}/tiles').path);

    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    if (zipData == null) {
      throw Exception('Failed to create ZIP archive');
    }

    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(zipData);

    return zipFile;
  }
  
  /// Merge multiple ZIP files into a single final ZIP
  Future<File> mergeZipFiles(List<File> zipFiles, {String outputName = 'offline_tiles_merged.zip'}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final outputPath = '${appDir.path}/$outputName';
    
    final mergedArchive = Archive();
    final addedPaths = <String>{};
    
    for (final zipFile in zipFiles) {
      if (!await zipFile.exists()) continue;
      
      try {
        final bytes = await zipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        for (final file in archive) {
          // Skip duplicates (in case of overlapping files)
          if (addedPaths.contains(file.name)) continue;
          
          if (file.isFile && file.content != null) {
            mergedArchive.addFile(ArchiveFile(
              file.name, 
              (file.content as List).length, 
              file.content,
            ));
            addedPaths.add(file.name);
          }
        }
      } catch (e) {
        // Skip corrupt files
        continue;
      }
    }
    
    if (mergedArchive.isEmpty) {
      throw Exception('No valid files found to merge');
    }
    
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(mergedArchive);
    
    if (zipData == null) {
      throw Exception('Failed to create merged ZIP archive');
    }
    
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(zipData);
    
    return outputFile;
  }
  
  /// Delete a specific ZIP file
  Future<void> deleteZipFile(File zipFile) async {
    if (await zipFile.exists()) {
      await zipFile.delete();
    }
  }
  
  /// Delete all part ZIP files
  Future<void> deleteAllPartZips() async {
    final partFiles = await getPartZipFiles();
    for (final file in partFiles) {
      await file.delete();
    }
  }

  /// Recursively add directory contents to archive
  Future<void> _addDirectoryToArchive(
    Archive archive,
    Directory directory,
    String basePath,
  ) async {
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final relativePath = entity.path.substring(basePath.length + 1);
        final fileData = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, fileData.length, fileData));
      }
    }
  }

  /// Verify ZIP file integrity
  Future<ZipVerificationResult> verifyZip(File zipFile) async {
    try {
      if (!await zipFile.exists()) {
        return ZipVerificationResult(
          isValid: false,
          errorMessage: 'ZIP file does not exist',
        );
      }

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      int totalFiles = 0;
      int validFiles = 0;

      for (final file in archive) {
        if (file.isFile) {
          totalFiles++;
          // Verify file can be read and has content
          if (file.content != null && (file.content as List).isNotEmpty) {
            validFiles++;
          }
        }
      }

      return ZipVerificationResult(
        isValid: totalFiles == validFiles && totalFiles > 0,
        totalFiles: totalFiles,
        validFiles: validFiles,
      );
    } catch (e) {
      return ZipVerificationResult(
        isValid: false,
        errorMessage: 'Error verifying ZIP: $e',
      );
    }
  }

  /// Extract ZIP file to tiles directory
  Future<Directory> extractZip(File zipFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final extractDir = Directory('${appDir.path}/offline_tiles');

    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filePath = '${extractDir.path}/${file.name}';
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }

    return extractDir;
  }

  /// Get existing ZIP file if it exists
  Future<File?> getExistingZip({String fileName = 'offline_tiles.zip'}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final zipFile = File('${appDir.path}/$fileName');
    if (await zipFile.exists()) {
      return zipFile;
    }
    return null;
  }
}

/// Result of ZIP verification
class ZipVerificationResult {
  final bool isValid;
  final int totalFiles;
  final int validFiles;
  final String? errorMessage;

  const ZipVerificationResult({
    required this.isValid,
    this.totalFiles = 0,
    this.validFiles = 0,
    this.errorMessage,
  });
}
