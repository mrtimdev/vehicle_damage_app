import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/damage_report.dart';

/// Service responsible for automatically cropping component/damage regions
/// (such as Tires, Hydraulic lines, Engine components, Brakes, and Body panels)
/// from high-resolution vehicle inspection photos.
class AutoPartCropper {
  /// Crops a part from [sourceImageFile] using [box] with optional [paddingRatio].
  /// Returns the absolute path of the generated JPEG thumbnail, or null on failure.
  static Future<String?> cropPartFromImage({
    required File sourceImageFile,
    required BoundingBox box,
    required String outputFilePath,
    double paddingRatio = 0.10,
  }) async {
    try {
      if (!sourceImageFile.existsSync() || !box.isValid) return null;
      final bytes = await sourceImageFile.readAsBytes();
      if (bytes.isEmpty) return null;

      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final imgW = decoded.width;
      final imgH = decoded.height;

      final pxXmin = (box.xmin * imgW).toInt();
      final pxYmin = (box.ymin * imgH).toInt();
      final pxXmax = (box.xmax * imgW).toInt();
      final pxYmax = (box.ymax * imgH).toInt();

      final padX = ((pxXmax - pxXmin) * paddingRatio).toInt();
      final padY = ((pxYmax - pxYmin) * paddingRatio).toInt();

      final cropX = (pxXmin - padX).clamp(0, imgW - 1);
      final cropY = (pxYmin - padY).clamp(0, imgH - 1);
      final cropW = ((pxXmax + padX) - cropX).clamp(1, imgW - cropX);
      final cropH = ((pxYmax + padY) - cropY).clamp(1, imgH - cropY);

      final cropped = img.copyCrop(
        decoded,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      final jpgBytes = img.encodeJpg(cropped, quality: 88);
      final outFile = File(outputFilePath);
      if (!outFile.parent.existsSync()) {
        outFile.parent.createSync(recursive: true);
      }
      await outFile.writeAsBytes(jpgBytes);
      return outFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Iterates through [report.items] and auto-crops all items having valid bounding boxes.
  /// Updates each [DamageItem] with its persisted [DamageItem.croppedImagePath].
  static Future<DamageReport> cropReportParts(
    DamageReport report, {
    Directory? targetDir,
  }) async {
    if (report.items.isEmpty) return report;

    Directory dir;
    if (targetDir != null) {
      dir = targetDir;
    } else {
      try {
        final docs = await getApplicationDocumentsDirectory();
        dir = Directory(p.join(docs.path, 'part_crops', report.id));
      } catch (_) {
        dir = Directory(p.join(Directory.systemTemp.path, 'part_crops', report.id));
      }
    }

    final mediaList = report.allMediaPaths;
    final updatedItems = <DamageItem>[];

    for (var i = 0; i < report.items.length; i++) {
      final item = report.items[i];

      // Keep already-cropped valid file
      if (item.croppedImagePath != null &&
          item.croppedImagePath!.isNotEmpty &&
          File(item.croppedImagePath!).existsSync()) {
        updatedItems.add(item);
        continue;
      }

      if (item.boundingBox != null && item.boundingBox!.isValid) {
        final targetImageIndex = item.imageIndex.clamp(0, mediaList.length - 1);
        if (mediaList.isNotEmpty && targetImageIndex < mediaList.length) {
          final sourcePath = mediaList[targetImageIndex];
          final sourceFile = File(sourcePath);
          if (sourceFile.existsSync()) {
            final partSlug = item.partName
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]'), '_')
                .replaceAll(RegExp(r'_+'), '_');
            final outPath = p.join(
              dir.path,
              'crop_${i}_$partSlug.jpg',
            );
            final cropped = await cropPartFromImage(
              sourceImageFile: sourceFile,
              box: item.boundingBox!,
              outputFilePath: outPath,
            );
            if (cropped != null) {
              updatedItems.add(item.copyWith(croppedImagePath: cropped));
              continue;
            }
          }
        }
      }

      updatedItems.add(item);
    }

    return report.copyWith(items: updatedItems);
  }
}
