part of 'progress_review_evaluation.dart';

ProgressReviewDomainId? _domainIdFromAction(ActionDirective action) {
  final group = action.groupLabel?.trim();
  if (group != null && group.isNotEmpty) {
    return ProgressReviewDomainIdLabels.resolveFromDisplayName(group);
  }
  return switch (action.categoryEnum) {
    InsightItemCategory.health => ProgressReviewDomainId.health,
    InsightItemCategory.expenses => ProgressReviewDomainId.expenses,
    InsightItemCategory.transport => ProgressReviewDomainId.location,
    InsightItemCategory.gaming => ProgressReviewDomainId.gaming,
    InsightItemCategory.calendar => ProgressReviewDomainId.calendar,
    InsightItemCategory.general => null,
  };
}

AnalysisDataSourceId _sourceId(ProgressReviewDomainId id) => switch (id) {
  ProgressReviewDomainId.health => AnalysisDataSourceId.health,
  ProgressReviewDomainId.expenses => AnalysisDataSourceId.expenses,
  ProgressReviewDomainId.location => AnalysisDataSourceId.location,
  ProgressReviewDomainId.gaming => AnalysisDataSourceId.gameActivity,
  ProgressReviewDomainId.calendar => AnalysisDataSourceId.calendar,
};

String _dataSnapshotKey(ProgressReviewDomainId id) => switch (id) {
  ProgressReviewDomainId.health => 'health',
  ProgressReviewDomainId.expenses => 'expenses',
  ProgressReviewDomainId.location => 'location',
  ProgressReviewDomainId.gaming => 'gameActivity',
  ProgressReviewDomainId.calendar => 'calendar',
};

bool _isExcludedSnapshot(String? value) {
  if (value == null || value.trim().isEmpty) return true;
  return value.trim().toLowerCase() ==
      kProgressReviewExcludedDataMessage.toLowerCase();
}

List<ActionDirective> _expenseChecklistActions(InsightsParsedReport report) {
  final actions = <ActionDirective>[];
  for (var week = 0; week < report.checklistWeekCount; week++) {
    for (final action in report.actionsForWeekIndex(week)) {
      if (_domainIdFromAction(action) == ProgressReviewDomainId.expenses) {
        actions.add(action);
      }
    }
  }
  return actions;
}

double? parseMonthlyIncomeBdt(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

double? extractSpendingCapBdt(List<ActionDirective> expenseActions) {
  double? best;
  for (final action in expenseActions) {
    final text = '${action.title} ${action.description}';
    final capMatch = RegExp(
      r'(?:below|under|at or below|cap(?:ped)? at|limit(?:ed)? to|outlays at or below)\s*\**([\d,]+)\s*BDT',
      caseSensitive: false,
    ).firstMatch(text);
    if (capMatch != null) {
      final value = double.tryParse(capMatch.group(1)!.replaceAll(',', ''));
      if (value != null) {
        best = best == null ? value : (value > best ? value : best);
      }
      continue;
    }

    for (final match in RegExp(
      r'([\d,]+)\s*BDT',
      caseSensitive: false,
    ).allMatches(text)) {
      final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (value == null) continue;
      best = best == null ? value : (value > best ? value : best);
    }
  }
  return best;
}

String _correctIncomePercentClaims(
  String markdown,
  VerifiedFinancialRatios ratios,
) {
  final actualPct = ratios.actualPercentOfIncome;
  if (actualPct == null) return markdown;

  final verifiedActual = formatPercent1dp(actualPct);
  final capPct = ratios.capPercentOfIncome;
  final headroom = ratios.headroomPercentUnderCap;

  var result = markdown;

  result = result.replaceAllMapped(
    RegExp(
      r'(\d{1,3}(?:\.\d+)?)\s*%\s*of\s*monthly\s*income',
      caseSensitive: false,
    ),
    (match) {
      final stated = double.tryParse(match.group(1)!);
      if (stated == null) return match.group(0)!;
      if ((stated - actualPct).abs() > 0.05) {
        return '$verifiedActual of monthly income';
      }
      return match.group(0)!;
    },
  );

  if (capPct != null && headroom != null) {
    final verifiedCap = formatPercent1dp(capPct);
    final verifiedHeadroom = formatPercent1dp(headroom);

    result = result.replaceAllMapped(
      RegExp(
        r'(\d{1,3}(?:\.\d+)?)\s*%\s*cap\s*minus\s*(\d{1,3}(?:\.\d+)?)\s*%\s*actual',
        caseSensitive: false,
      ),
      (match) => '$verifiedCap cap minus $verifiedActual actual',
    );

    result = result.replaceAllMapped(
      RegExp(
        r'headroom(?:\s+remaining)?(?:\s+under\s+cap)?:\s*(\d{1,3}(?:\.\d+)?)\s*%',
        caseSensitive: false,
      ),
      (match) {
        final stated = double.tryParse(match.group(1)!);
        if (stated == null) return match.group(0)!;
        if ((stated - headroom).abs() > 0.05) {
          return 'Headroom remaining under cap: $verifiedHeadroom';
        }
        return match.group(0)!;
      },
    );
  }

  return result;
}

String _rewriteExpenseDomainDelta(
  String markdown,
  VerifiedFinancialRatios ratios,
) {
  final domainPattern = RegExp(
    r'(####\s*\*\*(?:Expenses(?:\s*&\s*Cashew\s*App)?)\*\*\s*\n(?:.*\n)*?)(\* \*\*Delta:\*\*[^\n]*)',
    caseSensitive: false,
    multiLine: true,
  );

  return markdown.replaceAllMapped(domainPattern, (match) {
    final prefix = match.group(1)!;
    return '$prefix* **Delta:** ${ratios.buildExpenseDeltaLine()}';
  });
}

String _enforceExcludedDomains(
  String markdown,
  ProgressReviewEvaluationContext context,
) {
  var result = markdown;

  for (final domain in context.excludedDomains) {
    final escaped = RegExp.escape(domain.displayName);
    final sectionPattern = RegExp(
      '####\\s*\\*\\*$escaped\\*\\*\\s*\\n(?:.*\\n)*?(?=####\\s*\\*\\*|###\\s*\\*\\*|\$)',
      caseSensitive: false,
      multiLine: true,
    );

    final replacement =
        '#### **${domain.displayName}**\n\n$kProgressReviewDomainExcludedBullet\n';

    result = result.replaceAll(sectionPattern, replacement);

    // Legacy checklist / model output used "Expenses & Cashew App".
    if (domain.id == ProgressReviewDomainId.expenses) {
      final legacyPattern = RegExp(
        '####\\s*\\*\\*Expenses\\s*&\\s*Cashew\\s*App\\*\\*\\s*\\n(?:.*\\n)*?(?=####\\s*\\*\\*|###\\s*\\*\\*|\$)',
        caseSensitive: false,
        multiLine: true,
      );
      result = result.replaceAll(
        legacyPattern,
        '#### **Expenses**\n\n$kProgressReviewDomainExcludedBullet\n',
      );
    }
  }

  return result;
}

ProgressReviewParsedReport _applyEligibilityToParsedReport(
  ProgressReviewParsedReport parsed,
  ProgressReviewEvaluationContext context,
) {
  final excludedNames = {
    for (final d in context.excludedDomains) d.displayName.toLowerCase(),
    if (context.excludedDomains.any(
      (d) => d.id == ProgressReviewDomainId.expenses,
    ))
      'expenses',
  };

  final domains = parsed.domains.map((domain) {
    final normalized = domain.name.trim().toLowerCase();
    final id = ProgressReviewDomainIdLabels.resolveFromDisplayName(domain.name);
    final eligibility = id == null
        ? null
        : context.domainEligibility.firstWhere((d) => d.id == id);

    final excluded =
        excludedNames.contains(normalized) ||
        (eligibility != null && !eligibility.isScorable) ||
        _isDomainExcludedContent(domain);

    if (!excluded) return domain;

    return ProgressReviewDomain(
      name: domain.name,
      checklistTarget: null,
      actualOutcome: null,
      verdict: 'N/A',
      score: 'N/A',
      delta: null,
      isExcluded: true,
    );
  }).toList();

  return ProgressReviewParsedReport(
    checklistAdherence: parsed.checklistAdherence,
    dataBackedSummary: parsed.dataBackedSummary,
    overallScore: parsed.overallScore,
    domains: domains,
    whatWorked: parsed.whatWorked,
    gaps: parsed.gaps,
  );
}

bool _isDomainExcludedContent(ProgressReviewDomain domain) {
  final fields = [
    domain.checklistTarget,
    domain.actualOutcome,
    domain.verdict,
    domain.score,
    domain.delta,
  ].whereType<String>().join(' ').toLowerCase();

  return fields.contains('domain excluded');
}
