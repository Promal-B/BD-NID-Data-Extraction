import 'dart:io';
import 'dart:typed_data';

import 'package:human_security/human_security.dart';

import '../config/verification_config.dart';

/// 1:1 comparison using the package's bundled face-embedding model
/// (same model for reference and live face; cosine similarity).
class FaceRecognitionService {
  Future<FaceMatchReport> compare({
    required Uint8List referenceBytes,
    required File capturedImage,
    required VerificationResult liveness,
  }) async {
    final service = FaceMatchService(
      matchThreshold: VerificationConfig.matchThreshold,
    );
    try {
      await service.initialize();
      return await service.compareWithReference(
        reference: ReferenceImageSource.bytes(referenceBytes),
        capturedImage: capturedImage,
        livenessResult: liveness,
      );
    } finally {
      await service.dispose();
    }
  }
}
