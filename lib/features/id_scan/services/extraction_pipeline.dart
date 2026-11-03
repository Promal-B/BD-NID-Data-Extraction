import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/extracted_id.dart';
import 'barcode_extractor.dart';
import 'bd_nid_extractor.dart';
import 'mrz_extractor.dart';

/// Runs every extractor and merges per field (no early return), so a
/// validated MRZ value wins but printed-zone fields still fill the gaps.
class ExtractionPipeline {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _mrz = MrzExtractor();
  final _barcode = BarcodeExtractor();
  final _bd = BdNidExtractor();

  Future<ExtractedId> run(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final text = await _recognizer.processImage(input);

    // DEBUG: raw OCR dump. Remove before release (personal data).
    if (kDebugMode) {
      for (final b in text.blocks) {
        for (final l in b.lines) {
          debugPrint(
            '[${l.boundingBox.left.toInt()},${l.boundingBox.top.toInt()}] "${l.text}"',
          );
        }
      }
    }

    var result = _bd.extract(text);

    final mrz = _mrz.extract(text);
    if (mrz != null) result = mrz.mergeWith(result);

    final bc = await _barcode.extract(input);
    if (bc != null) result = bc.mergeWith(result);

    return result;
  }

  Future<void> dispose() => _recognizer.close();
}
