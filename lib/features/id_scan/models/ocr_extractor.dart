import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/extracted_id.dart';

class OcrExtractor {
  static final _surnameLabel = RegExp(
    r'surname|last\s*name',
    caseSensitive: false,
  );
  static final _givenLabel = RegExp(
    r'given\s*names?|first\s*name',
    caseSensitive: false,
  );
  static final _numberLabel = RegExp(
    r'(document|doc\.?|id|card)\s*(no|number|nr)|^no\.?$',
    caseSensitive: false,
  );
  static final _dobLabel = RegExp(r'birth|dob', caseSensitive: false);
  static final _expiryLabel = RegExp(
    r'expiry|expires|expiration|valid\s*until',
    caseSensitive: false,
  );

  ExtractedId extract(RecognizedText text) {
    final id = ExtractedId();

    final surname = _valueNextToLabel(text, _surnameLabel);
    if (surname != null) id.surname = Field(_cleanName(surname), Source.ocr);

    final given = _valueNextToLabel(text, _givenLabel);
    if (given != null) id.givenNames = Field(_cleanName(given), Source.ocr);

    final number = _valueNextToLabel(text, _numberLabel);
    if (number != null) {
      id.documentNumber = Field(
        number.replaceAll(RegExp(r'\s'), '').toUpperCase(),
        Source.ocr,
      );
    }

    final dob = _parseDate(_valueNextToLabel(text, _dobLabel));
    if (dob != null && dob.isBefore(DateTime.now())) {
      id.birthDate = Field(dob, Source.ocr);
    }

    final exp = _parseDate(_valueNextToLabel(text, _expiryLabel));
    if (exp != null) id.expiryDate = Field(exp, Source.ocr);

    return id;
  }

  String? _valueNextToLabel(RecognizedText t, RegExp label) {
    final allLines = t.blocks.expand((b) => b.lines).toList();

    for (final line in allLines) {
      if (!label.hasMatch(line.text)) continue;
      final lb = line.boundingBox;

      TextLine? best;
      double bestDist = double.infinity;
      for (final other in allLines) {
        if (identical(other, line)) continue;
        final ob = other.boundingBox;

        final sameRow =
            (ob.center.dy - lb.center.dy).abs() < lb.height * 0.6 &&
            ob.left > lb.right;
        final below =
            ob.top >= lb.bottom - 4 &&
            ob.top - lb.bottom < lb.height * 2 &&
            (ob.left - lb.left).abs() < lb.width;
        if (!sameRow && !below) continue;

        final d = (ob.center - lb.center).distance;
        if (d < bestDist) {
          bestDist = d;
          best = other;
        }
      }
      if (best != null) return best.text.trim();
    }
    return null;
  }

  String _cleanName(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z\s\-\x27]'), '').trim();

  DateTime? _parseDate(String? s) {
    if (s == null) return null;
    final m = RegExp(r'(\d{2})[./-](\d{2})[./-](\d{4})').firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final y = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, mo, d);
    return dt.month == mo ? dt : null;
  }
}
