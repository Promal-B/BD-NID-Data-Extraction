import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../config/verification_config.dart';
import '../../utils/image_utils.dart';
import 'face_detection_service.dart';

enum ExtractionStatus {
  success,
  noFace,
  ambiguousFaces,
  unsuitable,
  unreadableImage,
  error,
}

class FaceExtractionResult {
  const FaceExtractionResult({
    required this.status,
    required this.message,
    this.faceJpeg,
    this.sourceJpeg,
    this.faceCount = 0,
    this.faceBox,
  });

  final ExtractionStatus status;

  /// Human-readable explanation, safe to show in the UI.
  final String message;

  /// Cropped face (only when [isSuccess]). This is the reference for matching.
  final Uint8List? faceJpeg;

  /// Upright, size-capped copy of the selected image (for preview).
  final Uint8List? sourceJpeg;

  final int faceCount;

  /// Selected face box in [sourceJpeg] coordinates.
  final Rect? faceBox;

  bool get isSuccess => status == ExtractionStatus.success;
}

/// Finds the subject's face in an arbitrary photo (selfie, passport, ID card),
/// crops it and decides whether it is suitable as a matching reference.
///
/// ID cards often show several faces (main portrait, ghost portrait, back
/// side). The dominant, clearly largest face is taken as the holder's portrait;
/// if no face clearly dominates the image is rejected as ambiguous.
class FaceExtractionService {
  FaceExtractionService(this._detection);

  final FaceDetectionService _detection;

  Future<FaceExtractionResult> extract(Uint8List rawBytes) async {
    // 1. Decode + EXIF-bake + cap size (off the UI thread).
    final Uint8List upright;
    final img.Image image;
    try {
      upright = await compute(normalizeImageBytes, rawBytes);
      final decoded = img.decodeJpg(upright);
      if (decoded == null) throw const FormatException('decode failed');
      image = decoded;
    } catch (_) {
      return const FaceExtractionResult(
        status: ExtractionStatus.unreadableImage,
        message: 'This file could not be read as an image. Choose a JPEG or PNG photo.',
      );
    }

    // 2. Detect all faces (ML Kit needs a file; it is deleted right after).
    final List<Face> faces;
    try {
      faces = await _detectViaTempFile(upright);
    } catch (e) {
      return FaceExtractionResult(
        status: ExtractionStatus.error,
        message: 'Face detection failed: $e',
        sourceJpeg: upright,
      );
    }

    if (faces.isEmpty) {
      return FaceExtractionResult(
        status: ExtractionStatus.noFace,
        message: 'No face detected. Choose a sharp, well-lit photo where the face is clearly visible.',
        sourceJpeg: upright,
      );
    }

    // 3. Choose the primary face.
    final sorted = [...faces]..sort((a, b) => _area(b).compareTo(_area(a)));
    final primary = sorted.first;
    var note = '';
    if (sorted.length > 1) {
      final ratio = _area(primary) / _area(sorted[1]);
      if (ratio < VerificationConfig.dominantFaceAreaRatio) {
        return FaceExtractionResult(
          status: ExtractionStatus.ambiguousFaces,
          message:
              '${sorted.length} faces of similar size were found. '
              'Choose a photo where only one person is clearly the subject.',
          sourceJpeg: upright,
          faceCount: sorted.length,
        );
      }
      note = ' (${sorted.length} faces found – used the largest)';
    }

    // 4. Suitability checks on the original pixels.
    final box = primary.boundingBox;
    final problem = _checkSuitability(primary, image);
    if (problem != null) {
      return FaceExtractionResult(
        status: ExtractionStatus.unsuitable,
        message: problem,
        sourceJpeg: upright,
        faceCount: sorted.length,
        faceBox: box,
      );
    }

    // 5. Crop + normalise size.
    final crop = ImageUtils.cropFace(
      image,
      box,
      margin: VerificationConfig.faceCropMargin,
      minSide: VerificationConfig.faceCropMinSide,
      maxSide: VerificationConfig.faceCropMaxSide,
    );

    return FaceExtractionResult(
      status: ExtractionStatus.success,
      message: 'Face extracted$note.',
      faceJpeg: ImageUtils.encodeJpeg(crop),
      sourceJpeg: upright,
      faceCount: sorted.length,
      faceBox: box,
    );
  }

  /// Returns a user-facing reason, or null if the face is usable.
  String? _checkSuitability(Face face, img.Image image) {
    final box = face.boundingBox;
    if (box.shortestSide < VerificationConfig.minReferenceFacePx) {
      return 'The face is too small or low-resolution. Use a larger, closer photo.';
    }
    final yaw = (face.headEulerAngleY ?? 0).abs();
    final pitch = (face.headEulerAngleX ?? 0).abs();
    final roll = (face.headEulerAngleZ ?? 0).abs();
    if (yaw > VerificationConfig.maxReferenceYaw ||
        pitch > VerificationConfig.maxReferencePitch ||
        roll > VerificationConfig.maxReferenceRoll) {
      return 'The face is turned too far. Use a frontal photo.';
    }

    // Measure luma / sharpness on the tight face region only.
    final probe = ImageUtils.cropFace(
      image,
      box,
      margin: 0,
      minSide: 1,
      maxSide: 100000,
    );
    final luma = ImageUtils.meanLuma(probe);
    if (luma < VerificationConfig.minReferenceLuma) {
      return 'The face is too dark.';
    }
    if (luma > VerificationConfig.maxReferenceLuma) {
      return 'The face is overexposed.';
    }
    if (ImageUtils.sharpness(probe) <
        VerificationConfig.minReferenceSharpness) {
      return 'The face is too blurry for reliable matching.';
    }
    return null;
  }

  double _area(Face f) => f.boundingBox.width * f.boundingBox.height;

  Future<List<Face>> _detectViaTempFile(Uint8List jpeg) async {
    final dir = await Directory.systemTemp.createTemp('face_ref_');
    try {
      final file = File('${dir.path}/ref.jpg');
      await file.writeAsBytes(jpeg, flush: true);
      return await _detection.detectInFile(file.path);
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
