import 'dart:io';
import 'dart:typed_data';

import 'package:human_security/human_security.dart';

import '../config/verification_config.dart';
import '../models/face_verification_result.dart';
import 'face_detection_service.dart';
import 'face_extraction_service.dart';
import 'face_liveness_service.dart';
import 'face_recognition_service.dart';

class FaceVerificationService {
  FaceVerificationService() {
    extraction = FaceExtractionService(detection);
  }

  final detection = FaceDetectionService();
  late final FaceExtractionService extraction;
  final recognition = FaceRecognitionService();

  /// Detects, crops and validates the face in a gallery image.
  /// The returned [FaceExtractionResult.faceJpeg] is the reference for matching.
  Future<FaceExtractionResult> prepareReference(Uint8List rawImageBytes) =>
      extraction.extract(rawImageBytes);

  /// Never throws. Identity matching only runs if [liveness] passed.
  /// [referenceFaceJpeg] must be the cropped face from [prepareReference].
  /// The captured temp image is always deleted.
  Future<FaceVerificationResult> verify({
    required Uint8List referenceFaceJpeg,
    required LivenessOutcome liveness,
  }) async {
    final captured = liveness.image;

    if (!liveness.passed || captured == null || liveness.result == null) {
      await _safeDelete(captured);
      return FaceVerificationResult(
        outcome: VerificationOutcome.livenessFailed,
        message: liveness.message,
        livenessPassed: false,
        referenceJpeg: referenceFaceJpeg,
      );
    }

    try {
      final liveBytes = await captured.readAsBytes();
      final report = await recognition.compare(
        referenceBytes: referenceFaceJpeg,
        capturedImage: captured,
        liveness: liveness.result!,
      );
      final matched = report.isSamePerson;
      return FaceVerificationResult(
        outcome: matched
            ? VerificationOutcome.verified
            : VerificationOutcome.mismatch,
        message: matched
            ? 'Identity verified.'
            : 'The live face does not match the reference photo.',
        livenessPassed: true,
        similarity: report.similarityScore,
        threshold: VerificationConfig.matchThreshold,
        activeScore: liveness.active,
        passiveScore: liveness.passive,
        referenceJpeg: referenceFaceJpeg,
        liveJpeg: liveBytes,
      );
    } on ReferenceImageLoadException catch (e) {
      return FaceVerificationResult(
        outcome: VerificationOutcome.referenceInvalid,
        message: 'The reference face could not be processed: $e',
        livenessPassed: true,
        referenceJpeg: referenceFaceJpeg,
      );
    } on FaceMatchException catch (e) {
      // Typically: no usable face found in the reference crop or the live capture.
      return FaceVerificationResult(
        outcome: VerificationOutcome.error,
        message: 'Face comparison failed: $e',
        livenessPassed: true,
        activeScore: liveness.active,
        passiveScore: liveness.passive,
        referenceJpeg: referenceFaceJpeg,
      );
    } catch (e) {
      return FaceVerificationResult(
        outcome: VerificationOutcome.error,
        message: 'Technical error while comparing faces: $e',
        livenessPassed: true,
        activeScore: liveness.active,
        passiveScore: liveness.passive,
        referenceJpeg: referenceFaceJpeg,
      );
    } finally {
      await _safeDelete(captured);
    }
  }

  Future<void> _safeDelete(File? file) async {
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> dispose() => detection.dispose();
}
