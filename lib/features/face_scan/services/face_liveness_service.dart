import 'dart:io';

import 'package:human_security/human_security.dart';

import '../config/verification_config.dart';

/// Result of the guided liveness session (active challenges + passive PAD),
/// as produced by the package's [FaceLivenessDetector].
class LivenessOutcome {
  const LivenessOutcome._({
    required this.passed,
    required this.message,
    this.image,
    this.active,
    this.passive,
    this.result,
  });

  factory LivenessOutcome.failed(String reason) =>
      LivenessOutcome._(passed: false, message: reason);

  final bool passed;
  final String message;

  /// Captured live frame (only when [passed]). Delete after use.
  final File? image;
  final double? active;
  final double? passive;

  /// The package's own liveness result (needed for the match step).
  final VerificationResult? result;
}

abstract final class FaceLivenessService {
  /// Converts the widget's success callback into a strict pass/fail.
  /// Anything ambiguous counts as a failure (fail closed).
  static LivenessOutcome fromSuccess(File image, FaceMatchReport? report) {
    final r = report?.livenessResult;
    if (r == null) {
      return LivenessOutcome.failed('Liveness could not be confirmed.');
    }
    if (!r.isVerified) {
      return LivenessOutcome.failed(
        r.failureReason ?? 'Liveness check failed.',
      );
    }
    if (r.passiveScore < VerificationConfig.minPassiveScore) {
      return LivenessOutcome.failed(
        'Anti-spoofing check failed (possible photo or screen).',
      );
    }
    return LivenessOutcome._(
      passed: true,
      message: 'Liveness confirmed',
      image: image,
      active: r.activeScore,
      passive: r.passiveScore,
      result: r,
    );
  }
}
