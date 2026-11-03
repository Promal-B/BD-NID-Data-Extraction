import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/extracted_id.dart';
import '../models/barcode_extractor.dart';
import '../models/mrz_extractor.dart';
import '../models/ocr_extractor.dart';

/// Cascade: MRZ (check digits) -> barcode (structured) -> OCR (needs review).
class ExtractionPipeline {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _mrz = MrzExtractor();
  final _barcode = BarcodeExtractor();
  final _ocr = OcrExtractor();

  Future<ExtractedId> run(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final text = await _recognizer.processImage(input);

    final fromMrz = _mrz.extract(text);
    if (fromMrz != null) return fromMrz;

    final fromBarcode = await _barcode.extract(input);
    if (fromBarcode != null) return fromBarcode;

    return _ocr.extract(text);
  }

  Future<void> dispose() => _recognizer.close();
}
