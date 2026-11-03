import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../models/extracted_id.dart';

class BarcodeExtractor {
  Future<ExtractedId?> extract(InputImage image) async {
    final scanner = BarcodeScanner(formats: [BarcodeFormat.pdf417]);
    try {
      final barcodes = await scanner.processImage(image);
      for (final b in barcodes) {
        if (kDebugMode) debugPrint('BARCODE ${b.type} ${b.rawValue}');

        if (b.type != BarcodeType.driverLicense) continue;
        final dl = b.value as BarcodeDriverLicense;

        final id = ExtractedId();
        if (dl.licenseNumber != null) {
          id.documentNumber = Field(
            dl.licenseNumber!,
            Source.barcode,
            validated: true,
          );
        }
        if (dl.lastName != null) {
          id.surname = Field(dl.lastName!, Source.barcode, validated: true);
        }
        final given = [
          dl.firstName,
          dl.lastName,
        ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
        if (given.isNotEmpty) {
          id.givenNames = Field(given, Source.barcode, validated: true);
        }
        final dob = _parseDate(dl.birthDate);
        if (dob != null) {
          id.birthDate = Field(dob, Source.barcode, validated: true);
        }
        final exp = _parseDate(dl.expiryDate);
        if (exp != null) {
          id.expiryDate = Field(exp, Source.barcode, validated: true);
        }
        if (dl.gender != null) {
          id.sex = Field(dl.gender!, Source.barcode, validated: true);
        }
        return id.isEmpty ? null : id;
      }
      return null;
    } finally {
      await scanner.close();
    }
  }

  DateTime? _parseDate(String? s) {
    if (s == null || s.length != 8) return null;
    if (int.tryParse(s) == null) return null;

    final a = int.parse(s.substring(0, 4));
    if (a >= 1900 && a <= 2100) {
      return _safe(
        a,
        int.parse(s.substring(4, 6)),
        int.parse(s.substring(6, 8)),
      );
    }
    return _safe(
      int.parse(s.substring(4, 8)),
      int.parse(s.substring(0, 2)),
      int.parse(s.substring(2, 4)),
    );
  }

  DateTime? _safe(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, m, d);
    return dt.month == m ? dt : null;
  }
}
