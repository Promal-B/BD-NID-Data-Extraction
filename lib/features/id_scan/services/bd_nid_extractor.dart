import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/extracted_id.dart';

class BdNidExtractor {
  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  ExtractedId extract(RecognizedText text) {
    final rows = _rows(text);
    final id = ExtractedId();

    final nid = _nid(rows);
    if (nid != null) {
      id.documentNumber = Field(
        nid,
        Source.ocr,
        validated: const {10, 13, 17}.contains(nid.length),
      );
    }
    final dob = _dob(rows);
    if (dob != null) id.birthDate = Field(dob, Source.ocr);
    final name = _name(rows);
    if (name != null) id.fullName = Field(name, Source.ocr);
    return id;
  }

  List<String> _rows(RecognizedText t) {
    final lines = t.blocks.expand((b) => b.lines).toList()
      ..sort(
        (a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy),
      );

    final rows = <List<TextLine>>[];
    for (final l in lines) {
      if (rows.isNotEmpty) {
        final r = rows.last;
        final cy =
            r.map((e) => e.boundingBox.center.dy).reduce((a, b) => a + b) /
            r.length;
        if ((l.boundingBox.center.dy - cy).abs() < l.boundingBox.height * 0.6) {
          r.add(l);
          continue;
        }
      }
      rows.add([l]);
    }

    return [
      for (final r in rows)
        (r..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left)))
            .map((e) => e.text.trim())
            .join(' '),
    ];
  }

  String? _nid(List<String> rows) {
    String? fallback;
    for (final row in rows) {
      for (final m in RegExp(r'\d[\d ]{8,22}\d').allMatches(row)) {
        final digits = m.group(0)!.replaceAll(' ', '');
        if (digits.length < 10 || digits.length > 17) continue;
        if (RegExp(r'nid|id\s*no', caseSensitive: false).hasMatch(row)) {
          return digits;
        }
        fallback ??= digits;
      }
    }
    return fallback;
  }

  DateTime? _dob(List<String> rows) {
    final label = RegExp(r'date\s*o[ft]\s*birth|\bdob\b', caseSensitive: false);
    for (var i = 0; i < rows.length; i++) {
      if (!label.hasMatch(rows[i])) continue;
      for (final r in [rows[i], if (i + 1 < rows.length) rows[i + 1]]) {
        final d = _parseDate(r);
        if (d != null) return d;
      }
    }
    return null;
  }

  String? _name(List<String> rows) {
    final label = RegExp(r'\bname\b\s*[:\-]?\s*(.*)$', caseSensitive: false);
    for (var i = 0; i < rows.length; i++) {
      final m = label.firstMatch(rows[i]);
      if (m == null) continue;
      for (final cand in [
        m.group(1) ?? '',
        if (i + 1 < rows.length) rows[i + 1],
      ]) {
        final n = _latinName(cand);
        if (n != null) return n;
      }
    }
    return null;
  }

  String? _latinName(String s) {
    final t = s
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z .\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return RegExp(r'^[A-Z][A-Z .\-]{2,}$').hasMatch(t) ? t : null;
  }

  DateTime? _parseDate(String s) {
    final m = RegExp(r'(\d{1,2})\s*([A-Za-z]{3})[A-Za-z]*\.?,?\s*(\d{4})')
        .firstMatch(s);
    if (m != null) {
      final mo = _months[m.group(2)!.toLowerCase()];
      if (mo != null) {
        return _safe(int.parse(m.group(3)!), mo, int.parse(m.group(1)!));
      }
    }
    final n = RegExp(r'(\d{2})[./-](\d{2})[./-](\d{4})').firstMatch(s);
    if (n != null) {
      return _safe(
        int.parse(n.group(3)!),
        int.parse(n.group(2)!),
        int.parse(n.group(1)!),
      );
    }
    return null;
  }

  DateTime? _safe(int y, int m, int d) {
    final dt = DateTime(y, m, d);
    return (dt.month == m && dt.day == d) ? dt : null;
  }
}
