import '../models/extracted_id.dart';

/// ICAO 9303 TD1 (3 x 30) parser, with support for the document-number
/// overflow used by Bangladeshi NIDs (10-digit number: 9 digits in the
/// document-number field, the 10th digit + check digit in optional data).
class Td1Parser {
  static const _weights = [7, 3, 1];

  static int _value(String c) {
    final u = c.codeUnitAt(0);
    if (u >= 48 && u <= 57) return u - 48; // 0-9
    if (u >= 65 && u <= 90) return u - 55; // A-Z -> 10..35
    return 0; // '<'
  }

  static bool _checkOk(String data, String digit) {
    var sum = 0;
    for (var i = 0; i < data.length; i++) {
      sum += _value(data[i]) * _weights[i % 3];
    }
    return digit == '${sum % 10}';
  }

  // OCR confusion fixes, applied only where the field type is known.
  static String _digits(String s) => s
      .replaceAll('O', '0')
      .replaceAll('Q', '0')
      .replaceAll('I', '1')
      .replaceAll('Z', '2')
      .replaceAll('S', '5')
      .replaceAll('B', '8');

  static String _letters(String s) => s
      .replaceAll('0', 'O')
      .replaceAll('1', 'I')
      .replaceAll('5', 'S')
      .replaceAll('8', 'B');

  /// [lines] must be exactly 3 lines of 30 characters.
  static ExtractedId? parse(List<String> lines) {
    if (lines.length != 3 || lines.any((l) => l.length != 30)) return null;
    final l1 = lines[0], l2 = lines[1], l3 = lines[2];
    if (!'ACI'.contains(l1[0])) return null;

    final issuer = _letters(l1.substring(2, 5));
    String num(String s) => issuer == 'BGD' ? _digits(s) : s;

    // Document number (+ overflow into optional data)
    var docNo = l1.substring(5, 14);
    var docCd = l1.substring(14, 15);
    if (docCd == '<') {
      final tail = l1.substring(15).split('<').first;
      if (tail.length < 2) return null;
      docNo += tail.substring(0, tail.length - 1);
      docCd = tail.substring(tail.length - 1);
    }
    docNo = num(docNo);
    docCd = num(docCd);
    final docOk = _checkOk(docNo, docCd);

    // Dates (check digits must pass, otherwise wait for a better frame)
    final dobStr = _digits(l2.substring(0, 6));
    final expStr = _digits(l2.substring(8, 14));
    final dobOk = _checkOk(dobStr, _digits(l2.substring(6, 7)));
    final expOk = _checkOk(expStr, _digits(l2.substring(14, 15)));
    if (!dobOk || !expOk) return null;

    final birth = _date(dobStr, birth: true);
    final expiry = _date(expStr, birth: false);
    if (birth == null || expiry == null) return null;

    // Names: SURNAME<<GIVEN<NAMES
    final names = _letters(l3)
        .split('<<')
        .map((p) => p.replaceAll('<', ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final id = ExtractedId()
      ..documentNumber = Field(
        docNo.replaceAll('<', ''),
        Source.mrz,
        validated: docOk,
      )
      ..nationality = Field(_letters(l2.substring(15, 18)), Source.mrz)
      ..birthDate = Field(birth, Source.mrz, validated: true)
      ..expiryDate = Field(expiry, Source.mrz, validated: true);

    final sex = l2.substring(7, 8);
    if (sex == 'M' || sex == 'F') id.sex = Field(sex, Source.mrz);

    // Names have no check digit of their own, so they are not "validated".
    if (names.isNotEmpty) id.surname = Field(names[0], Source.mrz);
    if (names.length > 1) {
      id.givenNames = Field(names.sublist(1).join(' '), Source.mrz);
    }
    return id;
  }

  static DateTime? _date(String yymmdd, {required bool birth}) {
    final yy = int.tryParse(yymmdd.substring(0, 2));
    final mm = int.tryParse(yymmdd.substring(2, 4));
    final dd = int.tryParse(yymmdd.substring(4, 6));
    if (yy == null || mm == null || dd == null) return null;
    final nowYy = DateTime.now().year % 100;
    final year = birth ? (yy > nowYy ? 1900 + yy : 2000 + yy) : 2000 + yy;
    final d = DateTime(year, mm, dd);
    return (d.month == mm && d.day == dd) ? d : null;
  }
}
