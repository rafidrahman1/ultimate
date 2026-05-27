import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum InsightDomain { health, expenses, mobility, general }

enum InsightSectionKind { patterns, actions, other }

class InsightReport {
  const InsightReport({required this.sections});

  final List<InsightMajorSection> sections;

  bool get hasRichLayout =>
      sections.any((s) => s.subsections.any((sub) => sub.bullets.isNotEmpty));

  InsightMajorSection? get patternsSection {
    for (final section in sections) {
      if (section.kind == InsightSectionKind.patterns) return section;
    }
    return sections.isNotEmpty ? sections.first : null;
  }

  InsightMajorSection? get actionsSection {
    for (final section in sections) {
      if (section.kind == InsightSectionKind.actions) return section;
    }
    if (sections.length > 1) return sections.last;
    return null;
  }

  Iterable<InsightSubsection> get patternSubsections =>
      patternsSection?.subsections ?? const [];

  Iterable<InsightSubsection> get spendingSubsections =>
      patternSubsections.where(
        (s) =>
            s.domain == InsightDomain.expenses ||
            s.title.toLowerCase().contains('expense') ||
            s.title.toLowerCase().contains('budget'),
      );

  List<InsightBullet> get allPatternBullets => [
    for (final sub in patternSubsections) ...sub.bullets,
  ];

  List<({InsightBullet bullet, InsightDomain domain, String group})>
  get allActions {
    final items =
        <({InsightBullet bullet, InsightDomain domain, String group})>[];
    for (final sub in actionsSection?.subsections ?? const []) {
      for (final bullet in sub.bullets) {
        items.add((bullet: bullet, domain: sub.domain, group: sub.title));
      }
    }
    return items;
  }

  String? pulseLineFor(InsightDomain domain) {
    for (final sub in patternSubsections) {
      if (sub.domain != domain) continue;
      if (sub.bullets.isEmpty) continue;
      final bullet = sub.bullets.first;
      if (bullet.headline != null && bullet.headline!.isNotEmpty) {
        return bullet.headline;
      }
      final body = bullet.body.replaceAll('**', '').trim();
      if (body.length <= 48) return body;
      return '${body.substring(0, 45).trim()}…';
    }
    return null;
  }

  List<InsightHighlightMetric> get highlightMetrics {
    final seen = <String>{};
    final metrics = <InsightHighlightMetric>[];
    for (final section in sections) {
      for (final sub in section.subsections) {
        for (final bullet in sub.bullets) {
          for (final value in bullet.highlights) {
            if (!_looksLikeMetric(value)) continue;
            final key = value.toLowerCase();
            if (seen.contains(key)) continue;
            seen.add(key);
            metrics.add(
              InsightHighlightMetric(value: value, domain: sub.domain),
            );
            if (metrics.length >= 6) return metrics;
          }
        }
      }
    }
    return metrics;
  }
}

class InsightMajorSection {
  const InsightMajorSection({
    required this.title,
    this.number,
    required this.kind,
    required this.subsections,
  });

  final String title;
  final int? number;
  final InsightSectionKind kind;
  final List<InsightSubsection> subsections;
}

class InsightSubsection {
  const InsightSubsection({
    required this.title,
    required this.domain,
    required this.bullets,
  });

  final String title;
  final InsightDomain domain;
  final List<InsightBullet> bullets;
}

class InsightBullet {
  const InsightBullet({
    this.headline,
    required this.body,
    this.highlights = const [],
  });

  final String? headline;
  final String body;
  final List<String> highlights;

  String get displayText =>
      headline != null && headline!.isNotEmpty ? '$headline: $body' : body;
}

class InsightHighlightMetric {
  const InsightHighlightMetric({required this.value, required this.domain});

  final String value;
  final InsightDomain domain;
}

InsightDomain domainFromTitle(String title) {
  final lower = title.toLowerCase();
  if (lower.contains('health') ||
      lower.contains('sleep') ||
      lower.contains('heart') ||
      lower.contains('step')) {
    return InsightDomain.health;
  }
  if (lower.contains('expense') ||
      lower.contains('budget') ||
      lower.contains('financial') ||
      lower.contains('cash') ||
      lower.contains('snack')) {
    return InsightDomain.expenses;
  }
  if (lower.contains('mobility') ||
      lower.contains('motor') ||
      lower.contains('transport') ||
      lower.contains('bike') ||
      lower.contains('safety') ||
      lower.contains('location')) {
    return InsightDomain.mobility;
  }
  return InsightDomain.general;
}

InsightSectionKind kindFromTitle(String title) {
  final lower = title.toLowerCase();
  if (lower.contains('pattern') || lower.contains('anomal')) {
    return InsightSectionKind.patterns;
  }
  if (lower.contains('action') || lower.contains('plan')) {
    return InsightSectionKind.actions;
  }
  return InsightSectionKind.other;
}

Color domainColor(InsightDomain domain) {
  return switch (domain) {
    InsightDomain.health => AppColors.health,
    InsightDomain.expenses => AppColors.expenses,
    InsightDomain.mobility => AppColors.location,
    InsightDomain.general => AppColors.result,
  };
}

IconData domainIcon(InsightDomain domain, {bool forActions = false}) {
  if (forActions) {
    return switch (domain) {
      InsightDomain.health => Icons.bedtime_outlined,
      InsightDomain.expenses => Icons.savings_outlined,
      InsightDomain.mobility => Icons.two_wheeler_outlined,
      InsightDomain.general => Icons.task_alt_outlined,
    };
  }
  return switch (domain) {
    InsightDomain.health => Icons.favorite_outline,
    InsightDomain.expenses => Icons.account_balance_wallet_outlined,
    InsightDomain.mobility => Icons.route_outlined,
    InsightDomain.general => Icons.insights_outlined,
  };
}

bool _looksLikeMetric(String value) {
  if (!RegExp(r'\d').hasMatch(value)) return false;
  final lower = value.toLowerCase();
  return lower.contains('bdt') ||
      lower.contains('bpm') ||
      lower.contains('km') ||
      lower.contains('step') ||
      RegExp(r'\d\s*h').hasMatch(lower) ||
      RegExp(r'\d[,.]?\d*\s*m\b').hasMatch(lower) ||
      RegExp(r'^\d[\d,.]*$').hasMatch(value.trim());
}

/// Sleep-focused pattern card (metric + narrative).
class InsightSleepCardData {
  const InsightSleepCardData({
    required this.metric,
    required this.narrative,
    this.showWarning = true,
  });

  final String metric;
  final String narrative;
  final bool showWarning;
}

/// Spending leak vs one-off spike for the finance pattern card.
class InsightFinanceCardData {
  const InsightFinanceCardData({
    required this.leakLabel,
    required this.leakAmount,
    required this.spikeLabel,
    required this.spikeAmount,
  });

  final String leakLabel;
  final String leakAmount;
  final String spikeLabel;
  final String spikeAmount;
}

extension InsightDashboardViews on InsightReport {
  InsightSleepCardData? get sleepCard {
    final bullet = _firstPatternBulletMatching(
      (t) =>
          t.contains('sleep') ||
          t.contains('bedtime') ||
          t.contains('heart') ||
          t.contains('resting'),
    );
    if (bullet == null) return null;

    final metric =
        _firstMatch(
          bullet.highlights,
          RegExp(r'\d\s*h\s*\d*\s*m|\d+h\s*\d+m', caseSensitive: false),
        ) ??
        _firstMatch(
          [bullet.body, bullet.headline ?? ''],
          RegExp(
            r'\d\s*h\s*\d*\s*m of sleep|\d+h\s*\d+m',
            caseSensitive: false,
          ),
        );
    if (metric == null) return null;

    final narrative = _narrativeFor(
      bullet,
      fallbackDomain: InsightDomain.health,
    );
    return InsightSleepCardData(
      metric: metric.replaceAll(' of sleep', '').trim(),
      narrative: narrative,
      showWarning:
          narrative.toLowerCase().contains('late') ||
          narrative.toLowerCase().contains('deficit') ||
          narrative.toLowerCase().contains('low'),
    );
  }

  InsightFinanceCardData? get financeCard {
    final snackBullet = _firstPatternBulletMatching(
      (t) =>
          t.contains('snack') ||
          t.contains('drink') ||
          t.contains('food') ||
          t.contains('micro-spend') ||
          t.contains('restaurant'),
    );
    final spikeBullet = _firstPatternBulletMatching(
      (t) =>
          t.contains('gift') ||
          t.contains('electronics') ||
          t.contains('one-off') ||
          t.contains('largest expense'),
    );

    if (snackBullet == null && spikeBullet == null) return null;

    final combined = snackBullet ?? spikeBullet!;
    final amounts = _allBdtAmounts(combined);
    amounts.sort();

    String leakAmount = '—';
    String spikeAmount = '—';
    if (amounts.length >= 2) {
      leakAmount = '${_formatBdt(amounts.first)} BDT';
      spikeAmount = '${_formatBdt(amounts.last)} BDT';
    } else if (amounts.length == 1) {
      spikeAmount = '${_formatBdt(amounts.single)} BDT';
      leakAmount = snackBullet != null ? 'Micro-spend' : '—';
    } else {
      leakAmount = snackBullet != null
          ? _amountFromBullet(snackBullet) ?? '—'
          : '—';
      spikeAmount = spikeBullet != null
          ? _amountFromBullet(spikeBullet) ?? '—'
          : '—';
    }

    return InsightFinanceCardData(
      leakLabel: _financeLeakLabel(snackBullet ?? combined),
      leakAmount: leakAmount,
      spikeLabel: _financeSpikeLabel(spikeBullet ?? combined),
      spikeAmount: spikeAmount,
    );
  }

  InsightBullet? _firstPatternBulletMatching(bool Function(String text) test) {
    for (final sub in patternSubsections) {
      for (final bullet in sub.bullets) {
        final text = '${bullet.headline ?? ''} ${bullet.body}'.toLowerCase();
        if (test(text)) return bullet;
      }
    }
    return null;
  }

  String _narrativeFor(
    InsightBullet bullet, {
    required InsightDomain fallbackDomain,
  }) {
    if (bullet.body.trim().isNotEmpty) {
      return bullet.body.replaceAll('**', '').trim();
    }
    return bullet.headline ?? '';
  }

  String? _amountFromBullet(InsightBullet bullet) {
    for (final h in bullet.highlights) {
      if (h.toLowerCase().contains('bdt')) return h.replaceAll('**', '');
    }
    final match = RegExp(
      r'([\d,]+)\s*bdt',
      caseSensitive: false,
    ).firstMatch(bullet.body);
    return match != null ? '${match.group(1)} BDT' : null;
  }

  String _financeLeakLabel(InsightBullet bullet) {
    final text = '${bullet.headline ?? ''} ${bullet.body}'.toLowerCase();
    if (text.contains('snack') || text.contains('drink')) {
      return 'Snacks & drinks leak';
    }
    return 'Recurring micro-spend';
  }

  String _financeSpikeLabel(InsightBullet bullet) {
    final text = '${bullet.headline ?? ''} ${bullet.body}'.toLowerCase();
    if (text.contains('gift')) return 'Gift spike';
    if (text.contains('electronics')) return 'Electronics spike';
    return 'One-off spike';
  }

  List<double> _allBdtAmounts(InsightBullet bullet) {
    final amounts = <double>[];
    final sources = [...bullet.highlights, bullet.body];
    for (final source in sources) {
      for (final match in RegExp(
        r'([\d,]+)\s*bdt',
        caseSensitive: false,
      ).allMatches(source)) {
        final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (value != null) amounts.add(value);
      }
    }
    return amounts.toSet().toList()..sort();
  }

  String _formatBdt(double value) {
    if (value >= 1000) {
      return value
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
    }
    return value.toStringAsFixed(0);
  }

  String? _firstMatch(Iterable<String> sources, RegExp pattern) {
    for (final source in sources) {
      final match = pattern.firstMatch(source.replaceAll('**', ''));
      if (match != null) return match.group(0);
    }
    return null;
  }
}
