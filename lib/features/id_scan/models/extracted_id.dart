enum Source { nfc, mrz, barcode, ocr } // order = priority (lower index wins)

class Field<T> {
  final T value;
  final Source source;
  final bool validated; // check digit / signature / strict format passed

  const Field(this.value, this.source, {this.validated = false});

  @override
  String toString() => '$value';
}

class ExtractedId {
  Field<String>? documentNumber;
  Field<String>? surname;
  Field<String>? givenNames;
  Field<String>? fullName; // single printed "Name" field (e.g. Bangladesh NID)
  Field<String>? nationality;
  Field<String>? sex;
  Field<DateTime>? birthDate;
  Field<DateTime>? expiryDate;

  /// Cross-check mismatches between sources.
  final List<String> warnings = [];

  bool get isEmpty =>
      documentNumber == null &&
      surname == null &&
      givenNames == null &&
      fullName == null &&
      birthDate == null &&
      expiryDate == null;

  Map<String, Field<dynamic>?> get fields => {
    'Document number': documentNumber,
    'Full name': fullName,
    'Surname': surname,
    'Given names': givenNames,
    'Nationality': nationality,
    'Sex': sex,
    'Date of birth': birthDate,
    'Expiry date': expiryDate,
  };

  void _warn(String w) {
    if (!warnings.contains(w)) warnings.add(w);
  }

  /// Merges two results per field: validated beats unvalidated, then
  /// source priority (nfc > mrz > barcode > ocr). Records mismatches.
  ExtractedId mergeWith(ExtractedId o) {
    final r = ExtractedId();

    Field<T>? pick<T>(String label, Field<T>? a, Field<T>? b) {
      if (a == null || b == null) return a ?? b;
      if (a.value != b.value) {
        r._warn('$label differs: ${a.source.name} vs ${b.source.name}');
      }
      if (a.validated != b.validated) return a.validated ? a : b;
      return a.source.index <= b.source.index ? a : b;
    }

    r.documentNumber = pick(
      'Document number',
      documentNumber,
      o.documentNumber,
    );
    r.surname = pick('Surname', surname, o.surname);
    r.givenNames = pick('Given names', givenNames, o.givenNames);
    r.nationality = pick('Nationality', nationality, o.nationality);
    r.sex = pick('Sex', sex, o.sex);
    r.birthDate = pick('Date of birth', birthDate, o.birthDate);
    r.expiryDate = pick('Expiry date', expiryDate, o.expiryDate);
    r.fullName = pick('Full name', fullName, o.fullName);

    for (final w in [...warnings, ...o.warnings]) {
      r._warn(w);
    }

    // MRZ has surname + given names; the card prints one full name.
    final printed = r.fullName?.value;
    if (printed != null && r.surname != null) {
      final a = _tokens(printed);
      final b = _tokens('${r.givenNames?.value ?? ''} ${r.surname!.value}');
      if (a.length != b.length || !a.containsAll(b)) {
        r._warn('Printed name does not match MRZ name');
      }
    }
    return r;
  }

  static Set<String> _tokens(String s) => s
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z ]'), ' ')
      .split(' ')
      .where((t) => t.isNotEmpty)
      .toSet();

  Map<String, dynamic> toJson() => {
    'fields': {
      for (final e in fields.entries)
        if (e.value != null)
          e.key: {
            'value': e.value!.value is DateTime
                ? (e.value!.value as DateTime).toIso8601String()
                : e.value!.value,
            'source': e.value!.source.name,
            'validated': e.value!.validated,
          },
    },
    'warnings': warnings,
  };
}
