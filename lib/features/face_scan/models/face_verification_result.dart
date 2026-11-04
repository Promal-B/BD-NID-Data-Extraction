import 'dart:typed_data';

enum VerificationOutcome {
  verified,
  mismatch,
  livenessFailed,
  referenceInvalid,
  error,
}

class FaceVerificationResult {
  const FaceVerificationResult({
    required this.outcome,
    required this.message,
    required this.livenessPassed,
    this.similarity,
    this.threshold,
    this.activeScore,
    this.passiveScore,
    this.referenceJpeg,
    this.liveJpeg,
  });

  final VerificationOutcome outcome;
  final String message;
  final bool livenessPassed;
  final double? similarity;
  final double? threshold;
  final double? activeScore;
  final double? passiveScore;
  final Uint8List? referenceJpeg;
  final Uint8List? liveJpeg;

  bool get matched => outcome == VerificationOutcome.verified;
}
