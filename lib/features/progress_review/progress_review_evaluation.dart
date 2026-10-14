import 'package:personal/core/formatting.dart';
import 'package:personal/features/analysis/ui/analysis_data_preview.dart';
import 'package:personal/features/progress_review/progress_review_models.dart';
import 'package:personal/features/progress_review/progress_review_parser.dart';
import 'package:personal/features/results/reports/insights_models.dart';

part 'progress_review_enforcement.dart';

/// Canonical progress-review domains in checklist / output order.
enum ProgressReviewDomainId { health, expenses, location, gaming, calendar }

extension ProgressReviewDomainIdLabels on ProgressReviewDomainId {
  String get displayName => switch (this) {
    ProgressReviewDomainId.health => 'Health & Sleep',
    ProgressReviewDomainId.expenses => 'Expenses',
    ProgressReviewDomainId.location => 'Location & Mobility',
    ProgressReviewDomainId.gaming => 'Gaming & Leisure',
    ProgressReviewDomainId.calendar => 'Calendar & Schedule',
  };

  static ProgressReviewDomainId? resolveFromDisplayName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final id in ProgressReviewDomainId.values) {
      if (id.displayName.toLowerCase() == normalized) return id;
    }
    if (normalized == 'expenses' || normalized == 'expenses & cashew app') {
      return ProgressReviewDomainId.expenses;
    }
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
      ..writeln('- Actual expenses: ${formatBdt(actualExpensesBdt)} BDT')
      ..writeln('- Monthly baseline: ${formatBdt(monthlyBaselineBdt)} BDT');

    final actualPct = actualPercentOfIncome;
    if (actualPct != null) {
      buffer.writeln(
        '- Actual spend as % of income: ${formatPercent1dp(actualPct)} '
        '(= ${formatBdt(actualExpensesBdt)} / ${formatBdt(monthlyBaselineBdt)})',
      );
    }

    if (spendingCapBdt != null) {
      buffer.writeln('- Spending cap: ${formatBdt(spendingCapBdt!)} BDT');
      final capPct = capPercentOfIncome;
      final headroom = headroomPercentUnderCap;
      if (capPct != null) {
        buffer.writeln(
          '- Cap as % of income: ${formatPercent1dp(capPct)} '
          '(= ${formatBdt(spendingCapBdt!)} / ${formatBdt(monthlyBaselineBdt)})',
        );
      }
      if (headroom != null && actualPct != null) {
        buffer.writeln(
          '- Headroom under cap: ${formatPercent1dp(headroom)} '
          '(= ${formatPercent1dp(capPct!)} cap minus ${formatPercent1dp(actualPct)} actual)',
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
      return 'Actual spend is ${formatPercent1dp(actualPct)} of monthly income '
          '(${formatBdt(actualExpensesBdt)} BDT of ${formatBdt(monthlyBaselineBdt)} BDT). '
          'Headroom remaining under cap: ${formatPercent1dp(headroom)} '
          '(${formatPercent1dp(capPct)} cap minus ${formatPercent1dp(actualPct)} actual).';
    }

    return 'Actual spend is ${formatPercent1dp(actualPct)} of monthly income '
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
    final counts = {for (final id in _orderedDomains) id: 0};

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
      final dataExcluded =
          !selection.includes(_sourceId(id)) ||
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
      final cap = extractSpendingCapBdt(_expenseChecklistActions(checklist));
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
      ..writeln(
        '* **Delta:** [numeric change; use Verified financial ratios for income %]',
      );

    if (context.scorableDomains.isEmpty) {
      buffer.writeln();
      buffer.writeln(
        '(No scorable domains — omit Domain Progress section body.)',
      );
    }

    return buffer.toString().trimRight();
  }

  /// Post-processes AI markdown: fixes financial ratios and excluded domains.
  static String enforce(
    String rawMarkdown,
    ProgressReviewEvaluationContext context,
  ) {
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
