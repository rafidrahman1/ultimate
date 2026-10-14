part of 'outlook_ai.dart';

/// Asks the configured provider to refine the non-fuel predictions. Throws
/// when the reply can't be used, so the caller can keep what it has.
Future<OutlookAiEstimate> estimateOutlookWithAi({
  required AiSettings settings,
  required Iterable<CalendarEvent> events,
  required List<UpcomingCharge> bills,
  required String currency,
  MonthProjection? monthPace,
  BudgetOutlook? budget,
  PaydayOutlook? payday,
  BikeServiceForecast? bike,
  BikeServiceForecast? oil,
  String? rideContext,
  List<MonthlyExpenseRow> history = const [],
  Iterable<CashewTransaction> transactions = const [],
  Iterable<CashewTransaction> spending = const [],
  Iterable<TimelineActivity> activities = const [],
  Set<OutlookSection> sections = const {...OutlookSection.values},
  DateTime? now,
  AiClient client = const AiClient(maxAttempts: 2),
}) async {
  final clock = now ?? DateTime.now();
  final reply = await client.generate(
    settings: settings,
    systemInstruction: outlookAiSystemInstruction,
    prompt: buildOutlookAiPrompt(
      now: clock,
      currency: currency,
      events: events,
      bills: bills,
      monthPace: monthPace,
      budget: budget,
      payday: payday,
      bike: bike,
      oil: oil,
      rideContext: rideContext,
      history: history,
      transactions: transactions,
      spending: spending,
      activities: activities,
      sections: sections,
    ),
  );
  final estimate = parseOutlookAiResponse(
    reply,
    now: clock,
    bills: bills,
    sections: sections,
  );
  if (estimate == null) {
    final seen = reply.replaceAll(RegExp(r'\s+'), ' ').trim();
    throw FormatException(
      'The AI reply was not a usable estimate. It said: '
      '"${seen.length > 160 ? '${seen.substring(0, 160)}…' : seen}"',
    );
  }
  return estimate;
}
