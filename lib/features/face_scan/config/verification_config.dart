abstract final class VerificationConfig {
  // ───────────── Matching ─────────────
  /// Cosine similarity needed for "same person".
  /// The package default is 0.75, which is strict for ID-photo-vs-selfie pairs
  /// (low resolution, print texture, age gap). CALIBRATE this on real
  /// genuine/impostor pairs before relying on it.
  static const double matchThreshold = 0.65;

  // ───────────── Liveness ─────────────
  static const int challengeCount = 3;
  static const double minPassiveScore = 0.5;

  // ───────────── Reference face extraction (gallery / ID card) ─────────────
  /// Smallest face (as fraction of image width) the detector will report.
  /// Low on purpose: ID portraits are small inside a large card image.
  static const double detectorMinFaceSize = 0.03;

  /// If several faces are found (ghost portrait, back-side photo…), the largest
  /// is used only when its area is at least this many times the runner-up.
  /// Otherwise the image is rejected as ambiguous.
  static const double dominantFaceAreaRatio = 2.0;

  /// Extra context kept around the detected box (fraction of box size per side).
  static const double faceCropMargin = 0.25;

  /// The saved crop is scaled so its short side lies in this range.
  static const int faceCropMinSide = 384;
  static const int faceCropMaxSide = 1024;

  // Suitability gates (on the original image, before up-scaling)
  static const double minReferenceFacePx = 64;
  static const double maxReferenceYaw = 35;
  static const double maxReferencePitch = 30;
  static const double maxReferenceRoll = 35;
  static const double minReferenceLuma = 35;
  static const double maxReferenceLuma = 235;

  /// Variance of the Laplacian on a 160×160 grayscale crop. Typical sample ID
  /// photos measured ~240–1300; blurred images fall far below this.
  static const double minReferenceSharpness = 40;
}
