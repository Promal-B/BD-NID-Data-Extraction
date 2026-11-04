import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../config/verification_config.dart';

/// Thin wrapper around ML Kit face detection for still images.
class FaceDetectionService {
  FaceDetector? _detector;

  FaceDetector get _d => _detector ??= FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: VerificationConfig.detectorMinFaceSize,
    ),
  );

  /// Detects every face in the (already upright) image at [path].
  Future<List<Face>> detectInFile(String path) =>
      _d.processImage(InputImage.fromFilePath(path));

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}
