import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/progress_review/progress_review_models.dart';
import 'package:personal/features/progress_review/progress_review_parser.dart';
import 'package:personal/features/results/insights_models.dart';

/// Canonical progress-review domains in checklist / output order.
enum ProgressReviewDomainId {
  health,
  expenses,
  location,
  gaming,
  calendar,
}

extension ProgressReviewDomainIdLabels on ProgressReviewDomainId {
  String get displayName => switch (this) {
        ProgressReviewDomainId.health => 'Health & Sleep',
        ProgressReviewDomainId.expenses => 'Expenses & Cashew App',
        ProgressReviewDomainId.location => 'Location & Mobility',
        ProgressReviewDomainId.gaming => 'Gaming & Leisure',
        ProgressReviewDomainId.calendar => 'Calendar & Schedule',
      };

  static ProgressReviewDomainId? resolveFromDisplayName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final id in ProgressReviewDomainId.values) {
      if (id.displayName.toLowerCase() == normalized) return id;
    }
    if (normalized == 'expenses') return ProgressReviewDomainId.expenses;
    if (normalized.contains('health') || normalized.contains('sleep')) {
      return ProgressReviewDomainId.health;
    }
    if (normalized.contains('location') || normalized.contains('mobility')) {
      return ProgressReviewDomainId.location;
    }
    if (normalized.contains('gaming') || normalized.contains('leisure')) {
      return ProgressReviewDomainId.gaming;
    }
    if (normalized.contains('calendar') || normalized.contains('schedule')) {
      return ProgressReviewDomainId.calendar;
    }
    return null;
  }
}

const kProgressReviewExcludedDataMessage = 'Excluded from this analysis run.';
const kProgressReviewDomainExcludedBullet = '* **Domain excluded.**';

/// Per-domain eligibility for scoring in a progress review run.
class ProgressReviewDomainEligibility {
  const ProgressReviewDomainEligibility({
    required this.id,
    required this.displayName,
    required this.checklistTargetCount,
    required this.dataExcluded,
  });

  final ProgressReviewDomainId id;
  final String displayName;
  final int checklistTargetCount;
  final bool dataExcluded;

  bool get isScorable => checklistTargetCount > 0 && !dataExcluded;

  String get exclusionReason {
    if (checklistTargetCount == 0 && dataExcluded) {
      return 'no checklist targets and data excluded from this run';
    }
    if (checklistTargetCount == 0) {
      return 'no checklist targets defined in source checklist';
    }
    if (dataExcluded) return 'data excluded from this analysis run';
    return '';
  }
}

/// Strict, pre-computed expense ratios injected into prompts and enforcement.
class VerifiedFinancialRatios {
  const VerifiedFinancialRatios({
    required this.actualExpensesBdt,
    required this.monthlyBaselineBdt,
    this.spendingCapBdt,
  });

  final double actualExpensesBdt;
  final double monthlyBaselineBdt;
  final double? spendingCapBdt;

  double? get actualPercentOfIncome {
    if (monthlyBaselineBdt <= 0) return null;
    return (actualExpensesBdt / monthlyBaselineBdt) * 100;
  }

  double? get capPercentOfIncome {
    if (spendingCapBdt == null || monthlyBaselineBdt <= 0) return null;
    return (spendingCapBdt! / monthlyBaselineBdt) * 100;
  }

  double? get headroomPercentUnderCap {
    final capPct = capPercentOfIncome;
    final actualPct = actualPercentOfIncome;
    if (capPct == null || actualPct == null) return null;
    return capPct - actualPct;
  }

  String toPromptBlock() {
    if (monthlyBaselineBdt <= 0) {
      return 'Monthly baseline unavailable — do not compute income percentages.';
    }

    final buffer = StringBuffer()
      ..writeln(
        'Use ONLY these pre-computed ratios for any "% of monthly income" claims:',
      )
      ..writeln(
        '- Actual expenses: ${formatBdt(actualExpensesBdt)} BDT',
      )
      ..writeln(
        '- Monthly baseline: ${formatBdt(monthlyBaselineBdt)} BDT',
      );

    final actualPct = actualPercentOfIncome;
    if (actualPct != null) {
      buffer.writeln(
        '- Actual spend as % of income: ${formatPercent(actualPct)} '
        '(= ${formatBdt(actualExpensesBdt)} / ${formatBdt(monthlyBaselineBdt)})',
      );
    }

    if (spendingCapBdt != null) {
      buffer.writeln('- Spending cap: ${formatBdt(spendingCapBdt!)} BDT');
      final capPct = capPercentOfIncome;
      final headroom = headroomPercentUnderCap;
      if (capPct != null) {
        buffer.writeln(
          '- Cap as % of income: ${formatPercent(capPct)} '
          '(= ${formatBdt(spendingCapBdt!)} / ${formatBdt(monthlyBaselineBdt)})',
        );
      }
      if (headroom != null && actualPct != null) {
        buffer.writeln(
          '- Headroom under cap: ${formatPercent(headroom)} '
          '(= ${formatPercent(capPct!)} cap minus ${formatPercent(actualPct)} actual)',
        );
      }
    }

    return buffer.toString().trimRight();
  }

  String buildExpenseDeltaLine() {
    final actualPct = actualPercentOfIncome;
    if (actualPct == null) return 'Insufficient data to verify income ratio.';

    final capPct = capPercentOfIncome;
    final headroom = headroomPercentUnderCap;
    if (capPct != null && headroom != null) {
      return 'Actual spend is ${formatPercent(actualPct)} of monthly income '
          '(${formatBdt(actualExpensesBdt)} BDT of ${formatBdt(monthlyBaselineBdt)} BDT). '
          'Headroom remaining under cap: ${formatPercent(headroom)} '
          '(${formatPercent(capPct)} cap minus ${formatPercent(actualPct)} actual).';
    }

    return 'Actual spend is ${formatPercent(actualPct)} of monthly income '
        '(${formatBdt(actualExpensesBdt)} BDT of ${formatBdt(monthlyBaselineBdt)} BDT).';
  }
}

/// Input bundle for compiling and enforcing a progress review.
class ProgressReviewEvaluationContext {
  const ProgressReviewEvaluationContext({
    required this.domainEligibility,
    this.verifiedFinancialRatios,
  });

  final List<ProgressReviewDomainEligibility> domainEligibility;
  final VerifiedFinancialRatios? verifiedFinancialRatios;

  List<ProgressReviewDomainEligibility> get scorableDomains =>
      domainEligibility.where((d) => d.isScorable).toList();

  List<ProgressReviewDomainEligibility> get excludedDomains =>
      domainEligibility.where((d) => !d.isScorable).toList();
}

abstract final class ProgressReviewEvaluationEngine {
  ProgressReviewEvaluationEngine._();

  static const _orderedDomains = ProgressReviewDomainId.values;

  static Map<ProgressReviewDomainId, int> countChecklistTargetsByDomain(
    InsightsParsedReport report,
  ) {
    final counts = {
      for (final id in _orderedDomains) id: 0,
    };

    for (var week = 0; week < report.checklistWeekCount; week++) {
      for (final action in report.actionsForWeekIndex(week)) {
        final id = _domainIdFromAction(action);
        if (id != null) counts[id] = counts[id]! + 1;
      }
    }

    return counts;
  }

  static ProgressReviewEvaluationContext buildContext({
    required InsightsParsedReport checklist,
    required Map<String, String> dataSnapshot,
    required AnalysisSourceSelection selection,
    required String monthlyIncomeBdt,
    double? totalRealExpenses,
  }) {
    final targetCounts = countChecklistTargetsByDomain(checklist);
    final eligibility = <ProgressReviewDomainEligibility>[];

    for (final id in _orderedDomains) {
      final dataKey = _dataSnapshotKey(id);
      final snapshotValue = dataSnapshot[dataKey] ?? '';
      final dataExcluded = !selection.includes(_sourceId(id)) ||
          _isExcludedSnapshot(snapshotValue);

      eligibility.add(
        ProgressReviewDomainEligibility(
          id: id,
          displayName: id.displayName,
          checklistTargetCount: targetCounts[id] ?? 0,
          dataExcluded: dataExcluded,
        ),
      );
    }

    VerifiedFinancialRatios? ratios;
    final baseline = parseMonthlyIncomeBdt(monthlyIncomeBdt);
    if (baseline != null &&
        totalRealExpenses != null &&
        selection.includes(AnalysisDataSourceId.expenses) &&
        !_isExcludedSnapshot(dataSnapshot['expenses'])) {
      final cap = extractSpendingCapBdt(
        _expenseChecklistActions(checklist),
      );
      ratios = VerifiedFinancialRatios(
        actualExpensesBdt: totalRealExpenses,
        monthlyBaselineBdt: baseline,
        spendingCapBdt: cap,
      );
    }

    return ProgressReviewEvaluationContext(
      domainEligibility: eligibility,
      verifiedFinancialRatios: ratios,
    );
  }

  static String buildDomainScoringRulesBlock(
    ProgressReviewEvaluationContext context,
  ) {
    final buffer = StringBuffer();
    for (final domain in context.domainEligibility) {
      if (domain.isScorable) {
        buffer.writeln(
          '- ${domain.displayName}: SCORABLE (${domain.checklistTargetCount} checklist targets, data included)',
        );
      } else {
        buffer.writeln(
          '- ${domain.displayName}: EXCLUDED (${domain.exclusionReason}) — '
          'output only "$kProgressReviewDomainExcludedBullet" with no score',
        );
      }
    }
    return buffer.toString().trimRight();
  }

  static String buildDynamicOutputFormatBlock(
    ProgressReviewEvaluationContext context,
  ) {
    final buffer = StringBuffer()
      ..writeln('### **Domain Progress**')
      ..writeln()
      ..writeln(
        'Output #### subsections ONLY for SCORABLE domains listed in Domain scoring eligibility.',
      )
      ..writeln(
        'For EXCLUDED domains, output the #### header and exactly one bullet:',
      )
      ..writeln(kProgressReviewDomainExcludedBullet)
      ..writeln()
      ..writeln('For SCORABLE domains use:')
      ..writeln()
      ..writeln('#### **[Domain name]**')
      ..writeln()
      ..writeln('* **Checklist target:** [from checklist]')
      ..writeln('* **Actual outcome:** [from data]')
      ..writeln('* **Verdict:** [Improved | Partial | Unchanged | Declined]')
      ..writeln('* **Score:** [0–100]')
      ..writeln('* **Delta:** [numeric change; use Verified financial ratios for income %]');

    if (context.scorableDomains.isEmpty) {
      buffer.writeln();
      buffer.writeln('(No scorable domains — omit Domain Progress section body.)');
    }

    return buffer.toString().trimRight();
  }

  /// Post-processes AI markdown: fixes financial ratios and excluded domains.
  static String enforce(String rawMarkdown, ProgressReviewEvaluationContext context) {
    var output = rawMarkdown;

    if (context.verifiedFinancialRatios != null) {
      output = _correctIncomePercentClaims(
        output,
        context.verifiedFinancialRatios!,
      );
      output = _rewriteExpenseDomainDelta(
        output,
        context.verifiedFinancialRatios!,
      );
    }

    output = _enforceExcludedDomains(output, context);
    return output;
  }

  static ProgressReviewParsedReport parseEnforced(
    String rawMarkdown,
    ProgressReviewEvaluationContext context,
  ) {
    final enforced = enforce(rawMarkdown, context);
    final parsed = ProgressReviewParser.parse(enforced);
    return _applyEligibilityToParsedReport(parsed, context);
  }
}

ProgressReviewDomainId? _domainIdFromAction(ActionDirective action) {
  final group = action.groupLabel?.trim();
  if (group != null && group.isNotEmpty) {
    return ProgressReviewDomainIdLabels.resolveFromDisplayName(group);
  }
  return switch (action.categoryEnum) {
    InsightItemCategory.health => ProgressReviewDomainId.health,
    InsightItemCategory.expenses => ProgressReviewDomainId.expenses,
    InsightItemCategory.transport => ProgressReviewDomainId.location,
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
      if (value != null) best = best == null ? value : (value > best ? value : best);
      continue;
    }

    for (final match
        in RegExp(r'([\d,]+)\s*BDT', caseSensitive: false).allMatches(text)) {
      final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (value == null) continue;
      best = best == null ? value : (value > best ? value : best);
    }
  }
  return best;
}

String formatPercent(double percent) {
  final rounded = (percent * 10).roundToDouble() / 10;
  return '${rounded.toStringAsFixed(1)}%';
}

String formatBdt(double amount) {
  final rounded = (amount * 100).roundToDouble() / 100;
  return rounded.toStringAsFixed(2);
}

String _correctIncomePercentClaims(
  String markdown,
  VerifiedFinancialRatios ratios,
) {
  final actualPct = ratios.actualPercentOfIncome;
  if (actualPct == null) return markdown;

  final verifiedActual = formatPercent(actualPct);
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
    final verifiedCap = formatPercent(capPct);
    final verifiedHeadroom = formatPercent(headroom);

    result = result.replaceAllMapped(
      RegExp(
        r'(\d{1,3}(?:\.\d+)?)\s*%\s*cap\s*minus\s*(\d{1,3}(?:\.\d+)?)\s*%\s*actual',
        caseSensitive: false,
      ),
      (match) =>
          '$verifiedCap cap minus $verifiedActual actual',
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

    // Alternate header without "& Cashew App" for expenses.
    if (domain.id == ProgressReviewDomainId.expenses) {
      final altPattern = RegExp(
        '####\\s*\\*\\*Expenses\\*\\*\\s*\\n(?:.*\\n)*?(?=####\\s*\\*\\*|###\\s*\\*\\*|\$)',
        caseSensitive: false,
        multiLine: true,
      );
      result = result.replaceAll(
        altPattern,
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
    if (context.excludedDomains.any((d) => d.id == ProgressReviewDomainId.expenses))
      'expenses',
  };

  final domains = parsed.domains.map((domain) {
    final normalized = domain.name.trim().toLowerCase();
    final id = ProgressReviewDomainIdLabels.resolveFromDisplayName(domain.name);
    final eligibility = id == null
        ? null
        : context.domainEligibility.firstWhere((d) => d.id == id);

    final excluded = excludedNames.contains(normalized) ||
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
