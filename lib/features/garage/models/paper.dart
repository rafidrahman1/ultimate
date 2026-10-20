/// The papers a Bangladeshi rider keeps current (BRTA). Stored by name, so
/// [roadTax] is the tax token and [pollution] stays only for older saves.
enum PaperType {
  registration('Registration certificate', 60),
  roadTax('Tax token', 12),
  fitness('Fitness certificate', 12),
  insurance('Insurance', 12),
  licence('Driving licence', 60),
  other('Other', 12),
  pollution('Emission certificate', 12);

  const PaperType(this.label, this.typicalMonths);
  final String label;

  /// Usual validity, to suggest an expiry date for a new document.
  final int typicalMonths;

  /// Offered when adding a document; [pollution] is kept for old entries.
  static const choices = [
    registration,
    roadTax,
    fitness,
    insurance,
    licence,
    other,
  ];
}

/// A document that expires and has to be renewed.
class Paper {
  const Paper({
    required this.id,
    required this.bikeId,
    required this.type,
    required this.expiry,
    this.number = '',
    this.note = '',
  });

  factory Paper.fromJson(Map<String, dynamic> j) => Paper(
    id: j['id'] as String,
    bikeId: j['bikeId'] as String,
    type: PaperType.values.firstWhere(
      (c) => c.name == j['type'],
      orElse: () => PaperType.other,
    ),
    expiry: DateTime.parse(j['expiry'] as String),
    number: j['number'] as String? ?? '',
    note: j['note'] as String? ?? '',
  );

  final String id;
  final String bikeId;
  final PaperType type;
  final DateTime expiry;
  final String number;
  final String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bikeId': bikeId,
    'type': type.name,
    'expiry': expiry.toIso8601String(),
    'number': number,
    'note': note,
  };
}
