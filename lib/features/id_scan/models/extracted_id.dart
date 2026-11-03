enum Source { nfc, mrz, barcode, ocr }

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
  Field<String>? nationality;
  Field<String>? sex;
  Field<DateTime>? birthDate;
  Field<DateTime>? expiryDate;

  bool get isEmpty =>
      documentNumber == null &&
      surname == null &&
      givenNames == null &&
      birthDate == null &&
      expiryDate == null;

  /// Ordered list for display or serialization.
  Map<String, Field<dynamic>?> get fields => {
    'Document number': documentNumber,
    'Surname': surname,
    'Given names': givenNames,
    'Nationality': nationality,
    'Sex': sex,
    'Date of birth': birthDate,
    'Expiry date': expiryDate,
  };

  Map<String, dynamic> toJson() => {
    for (final e in fields.entries)
      if (e.value != null)
        e.key: {
          'value': e.value!.value is DateTime
              ? (e.value!.value as DateTime).toIso8601String()
              : e.value!.value,
          'source': e.value!.source.name,
          'validated': e.value!.validated,
        },
  };
}
