class ProgressReviewParsedReport {
  const ProgressReviewParsedReport({
    this.checklistAdherence,
    this.dataBackedSummary,
    this.overallScore,
    this.domains = const [],
    this.whatWorked = const [],
    this.gaps = const [],
  });

  final String? checklistAdherence;
  final String? dataBackedSummary;
  final String? overallScore;
  final List<ProgressReviewDomain> domains;
  final List<ProgressReviewBullet> whatWorked;
  final List<ProgressReviewBullet> gaps;

  bool get isEmpty =>
      checklistAdherence == null &&
      dataBackedSummary == null &&
      overallScore == null &&
      domains.isEmpty &&
      whatWorked.isEmpty &&
      gaps.isEmpty;
}

class ProgressReviewDomain {
  const ProgressReviewDomain({
    required this.name,
    this.checklistTarget,
    this.actualOutcome,
    this.verdict,
    this.score,
    this.delta,
  });

  final String name;
  final String? checklistTarget;
  final String? actualOutcome;
  final String? verdict;
  final String? score;
  final String? delta;
}

class ProgressReviewBullet {
  const ProgressReviewBullet({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}
