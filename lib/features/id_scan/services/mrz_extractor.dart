import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mrz_parser/mrz_parser.dart';

import '../models/extracted_id.dart';
import 'td1_parser.dart';

class MrzExtractor {
  /// Returns null if no valid MRZ is found (including failed check digits).
  ExtractedId? extract(RecognizedText text) {
    final lines = _findMrzLines(text);
    if (lines == null) return null;

    // TD1 (3 x 30), e.g. Bangladesh NID: custom parser handles number overflow.
    if (lines.length == 3) return Td1Parser.parse(lines);

    // TD2 / TD3 via the package
    try {
      final r = MRZParser.parse(lines); // throws if check digits fail
      return ExtractedId()
        ..documentNumber = Field(r.documentNumber, Source.mrz, validated: true)
        ..surname = Field(r.surnames, Source.mrz, validated: true)
        ..givenNames = Field(r.givenNames, Source.mrz, validated: true)
        ..nationality = Field(
          r.nationalityCountryCode,
          Source.mrz,
          validated: true,
        )
        ..sex = Field(r.sex.name, Source.mrz, validated: true)
        ..birthDate = Field(r.birthDate, Source.mrz, validated: true)
        ..expiryDate = Field(r.expiryDate, Source.mrz, validated: true);
    } catch (_) {
      return null; // misread; caller falls back or tries another frame
    }
  }

  List<String>? _findMrzLines(RecognizedText text) {
    final candidates = text.text
        .split('\n')
        .map(
          (l) => l
              .replaceAll(RegExp(r'\s'), '')
              .replaceAll('«', '<')
              .toUpperCase(),
        )
        .where((l) => l.contains('<') && RegExp(r'^[A-Z0-9<]+$').hasMatch(l))
        .toList();

    // TD3 (passport) 2x44, TD2 2x36, TD1 3x30
    for (final spec in const [(44, 2), (36, 2), (30, 3)]) {
      final (len, count) = spec;
      final group = candidates
          .where((l) => (l.length - len).abs() <= 2)
          .toList();
      if (group.length >= count) {
        return group
            .take(count)
            .map(
              (l) =>
                  l.length < len ? l.padRight(len, '<') : l.substring(0, len),
            )
            .toList();
      }
    }
    return null;
  }
}
