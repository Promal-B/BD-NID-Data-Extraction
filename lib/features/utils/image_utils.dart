import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

/// Top-level so it can run in an isolate via `compute`.
/// Decodes any supported format, applies EXIF orientation, caps the size and
/// re-encodes as JPEG (which also strips metadata such as EXIF/GPS).
Uint8List normalizeImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image');
  }
  var image = img.bakeOrientation(decoded);
  const maxSide = 2048;
  final longest = math.max(image.width, image.height);
  if (longest > maxSide) {
    final s = maxSide / longest;
    image = img.copyResize(
      image,
      width: (image.width * s).round(),
      height: (image.height * s).round(),
      interpolation: img.Interpolation.average,
    );
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

abstract final class ImageUtils {
  /// Crops [box] (+ [margin] on every side, clamped to the image) and scales the
  /// result so its short side lies within [minSide]…[maxSide].
  static img.Image cropFace(
    img.Image src,
    Rect box, {
    required double margin,
    required int minSide,
    required int maxSide,
  }) {
    final left = (box.left - box.width * margin).clamp(0.0, src.width - 1.0);
    final top = (box.top - box.height * margin).clamp(0.0, src.height - 1.0);
    final right = (box.right + box.width * margin).clamp(
      left + 1,
      src.width.toDouble(),
    );
    final bottom = (box.bottom + box.height * margin).clamp(
      top + 1,
      src.height.toDouble(),
    );

    var crop = img.copyCrop(
      src,
      x: left.floor(),
      y: top.floor(),
      width: (right - left).round().clamp(1, src.width).toInt(),
      height: (bottom - top).round().clamp(1, src.height).toInt(),
    );

    final shortSide = math.min(crop.width, crop.height);
    final longSide = math.max(crop.width, crop.height);
    double scale = 1;
    if (shortSide < minSide) {
      scale = minSide / shortSide;
    } else if (longSide > maxSide) {
      scale = maxSide / longSide;
    }
    if (scale != 1) {
      crop = img.copyResize(
        crop,
        width: (crop.width * scale).round(),
        height: (crop.height * scale).round(),
        interpolation: scale > 1
            ? img.Interpolation.cubic
            : img.Interpolation.average,
      );
    }
    return crop;
  }

  static double _luma(img.Pixel p) => 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

  /// Mean luma (0–255).
  static double meanLuma(img.Image im) {
    var sum = 0.0;
    var n = 0;
    final stepX = math.max(1, im.width ~/ 64);
    final stepY = math.max(1, im.height ~/ 64);
    for (var y = 0; y < im.height; y += stepY) {
      for (var x = 0; x < im.width; x += stepX) {
        sum += _luma(im.getPixel(x, y));
        n++;
      }
    }
    return n == 0 ? 0 : sum / n;
  }

  /// Variance of the Laplacian on a 160×160 grayscale copy (higher = sharper).
  static double sharpness(img.Image im) {
    const s = 160;
    final small = img.copyResize(
      im,
      width: s,
      height: s,
      interpolation: img.Interpolation.average,
    );
    final g = List<double>.generate(
      s * s,
      (i) => _luma(small.getPixel(i % s, i ~/ s)),
    );
    final lap = <double>[];
    for (var y = 1; y < s - 1; y++) {
      for (var x = 1; x < s - 1; x++) {
        final i = y * s + x;
        lap.add(g[i - 1] + g[i + 1] + g[i - s] + g[i + s] - 4 * g[i]);
      }
    }
    final mean = lap.reduce((a, b) => a + b) / lap.length;
    return lap.fold<double>(0, (a, v) => a + (v - mean) * (v - mean)) /
        lap.length;
  }

  static Uint8List encodeJpeg(img.Image im, {int quality = 95}) =>
      Uint8List.fromList(img.encodeJpg(im, quality: quality));
}
