import 'package:intl/intl.dart';

import 'package:personal/core/formatting.dart';
import 'package:personal/features/calendar/calendar_event_summary.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';

const _allDayNearbyWindowDays = 1;
const _postEventObservationWindow = Duration(days: 3);
const _timedDirectWindowBefore = Duration(minutes: 30);
const _timedDirectWindowAfter = Duration(minutes: 30);
const _timedNearbyWindowBefore = Duration(hours: 2);
const _timedNearbyWindowAfter = Duration(hours: 2);
const eventAssociationMinConfidence = 0.5;

enum ExpenseEventLinkType { direct, nearby, postEventLowConfidence, unrelated }

class ExpenseEventAssociation {
  const ExpenseEventAssociation({
    this.eventName,
    this.timingDetail,
    this.distanceMinutes,
    this.linkType = ExpenseEventLinkType.unrelated,
    this.confidence = 0,
  });

  final String? eventName;
  final String? timingDetail;
  final int? distanceMinutes;
  final ExpenseEventLinkType linkType;
  final double confidence;

  bool get hasAssociation =>
      (linkType == ExpenseEventLinkType.direct ||
          linkType == ExpenseEventLinkType.nearby) &&
      eventName != null &&
      timingDetail != null &&
      confidence >= eventAssociationMinConfidence;
}

ExpenseEventAssociation findExpenseEventAssociation({
  required CashewTransaction transaction,
  required List<MajorCalendarEvent> calendarEvents,
  int allDayWindowDays = _allDayNearbyWindowDays,
}) {
  final purchaseAt = transaction.date.toLocal();
  ExpenseEventAssociation? nearest;
  double? nearestConfidence;

  for (final event in calendarEvents) {
    final candidate = event.allDay || event.isHoliday
        ? _associationForAllDayEvent(
            purchaseAt: purchaseAt,
            event: event,
            windowDays: allDayWindowDays,
          )
        : _associationForTimedEvent(purchaseAt: purchaseAt, event: event);
    if (candidate == null) continue;

    if (candidate.hasAssociation &&
        (nearestConfidence == null ||
            candidate.confidence > nearestConfidence)) {
      nearest = candidate;
      nearestConfidence = candidate.confidence;
    } else if (nearest == null &&
        candidate.linkType == ExpenseEventLinkType.postEventLowConfidence) {
      nearest = candidate;
    }
  }

  return nearest ?? const ExpenseEventAssociation();
}

ExpenseEventAssociation? _associationForTimedEvent({
  required DateTime purchaseAt,
  required MajorCalendarEvent event,
}) {
  final eventStart = event.start.toLocal();
  final eventEnd = event.end.toLocal();
  if (!eventEnd.isAfter(eventStart)) return null;

  final distanceMinutes = _minutesFromEventWindow(
    purchaseAt,
    eventStart,
    eventEnd,
  );

  if (!purchaseAt.isBefore(eventStart) && !purchaseAt.isAfter(eventEnd)) {
    return ExpenseEventAssociation(
      eventName: event.title,
      timingDetail:
          'during event (${_formatExpenseDateTime(eventStart)}–'
          '${_formatExpenseDateTime(eventEnd)})',
      distanceMinutes: distanceMinutes,
      linkType: ExpenseEventLinkType.direct,
      confidence: 1.0,
    );
  }

  if (purchaseAt.isBefore(eventStart)) {
    final leadTime = eventStart.difference(purchaseAt);
    final linkType = leadTime <= _timedDirectWindowBefore
        ? ExpenseEventLinkType.direct
        : leadTime <= _timedNearbyWindowBefore
        ? ExpenseEventLinkType.nearby
        : ExpenseEventLinkType.unrelated;
    if (linkType == ExpenseEventLinkType.unrelated) return null;
    return ExpenseEventAssociation(
      eventName: event.title,
      timingDetail:
          '${_formatAssociationOffset(leadTime)} before event start '
          '(${_formatExpenseDateTime(eventStart)})',
      distanceMinutes: distanceMinutes,
      linkType: linkType,
      confidence: _timedConfidence(leadTime, _timedNearbyWindowBefore),
    );
  }

  final lagTime = purchaseAt.difference(eventEnd);
  final linkType = lagTime <= _timedDirectWindowAfter
      ? ExpenseEventLinkType.direct
      : lagTime <= _timedNearbyWindowAfter
      ? ExpenseEventLinkType.nearby
      : lagTime <= _postEventObservationWindow
      ? ExpenseEventLinkType.postEventLowConfidence
      : ExpenseEventLinkType.unrelated;
  if (linkType == ExpenseEventLinkType.unrelated) return null;
  if (linkType == ExpenseEventLinkType.postEventLowConfidence) {
    return ExpenseEventAssociation(
      eventName: event.title,
      timingDetail:
          '${_formatAssociationOffset(lagTime)} after event end '
          '(${_formatExpenseDateTime(eventEnd)})',
      distanceMinutes: distanceMinutes,
      linkType: linkType,
      confidence: 0.2,
    );
  }
  return ExpenseEventAssociation(
    eventName: event.title,
    timingDetail:
        '${_formatAssociationOffset(lagTime)} after event end '
        '(${_formatExpenseDateTime(eventEnd)})',
    distanceMinutes: distanceMinutes,
    linkType: linkType,
    confidence: _timedConfidence(lagTime, _timedNearbyWindowAfter),
  );
}

ExpenseEventAssociation? _associationForAllDayEvent({
  required DateTime purchaseAt,
  required MajorCalendarEvent event,
  required int windowDays,
}) {
  final purchaseDay = _dateOnly(purchaseAt);
  final eventStartDay = _dateOnly(event.start);
  final eventEndDay = _dateOnly(event.end);

  final int dayOffset;
  if (purchaseDay.isBefore(eventStartDay)) {
    dayOffset = -eventStartDay.difference(purchaseDay).inDays;
  } else if (purchaseDay.isAfter(eventEndDay)) {
    dayOffset = purchaseDay.difference(eventEndDay).inDays;
  } else {
    dayOffset = 0;
  }

  if (dayOffset.abs() > windowDays) {
    if (dayOffset > windowDays &&
        dayOffset <= _postEventObservationWindow.inDays) {
      return ExpenseEventAssociation(
        eventName: event.title,
        timingDetail:
            '$dayOffset day${dayOffset == 1 ? '' : 's'} after event end',
        distanceMinutes: dayOffset.abs() * 24 * 60,
        linkType: ExpenseEventLinkType.postEventLowConfidence,
        confidence: 0.2,
      );
    }
    return null;
  }

  final linkType = dayOffset == 0
      ? ExpenseEventLinkType.direct
      : ExpenseEventLinkType.nearby;
  final timingDetail = switch (dayOffset) {
    < 0 =>
      '${dayOffset.abs()} day${dayOffset.abs() == 1 ? '' : 's'} '
          'before event start',
    > 0 => '$dayOffset day${dayOffset == 1 ? '' : 's'} after event end',
    _ => 'during event dates',
  };

  return ExpenseEventAssociation(
    eventName: event.title,
    timingDetail: timingDetail,
    distanceMinutes: dayOffset.abs() * 24 * 60,
    linkType: linkType,
    confidence: dayOffset == 0 ? 0.9 : 0.55,
  );
}

double _timedConfidence(Duration offset, Duration maxNearby) {
  if (maxNearby.inMinutes <= 0) return 0;
  final ratio = 1 - offset.inMinutes / maxNearby.inMinutes;
  return (0.5 + ratio * 0.4).clamp(0.5, 0.95);
}

int _minutesFromEventWindow(
  DateTime purchaseAt,
  DateTime eventStart,
  DateTime eventEnd,
) {
  if (!purchaseAt.isBefore(eventStart) && !purchaseAt.isAfter(eventEnd)) {
    return 0;
  }
  if (purchaseAt.isBefore(eventStart)) {
    return eventStart.difference(purchaseAt).inMinutes;
  }
  return purchaseAt.difference(eventEnd).inMinutes;
}

String _formatAssociationOffset(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes < 60) return '${totalMinutes}m';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _formatExpenseDateTime(DateTime dateTime) =>
    DateFormat('d MMM HH:mm').format(dateTime.toLocal());

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String formatExpenseDate(DateTime date) =>
    DateFormat('d MMM').format(date.toLocal());

String formatExpenseMoney(double amount, {bool alwaysTwoDecimals = false}) {
  final rounded = roundTo2dp(amount.abs());
  final negative = amount < 0;

  if (alwaysTwoDecimals) {
    return _formatGroupedAmount(rounded, decimals: 2, negative: negative);
  }

  if (rounded == rounded.roundToDouble()) {
    return _formatGroupedAmount(rounded, decimals: 0, negative: negative);
  }

  return _formatGroupedAmount(rounded, decimals: 2, negative: negative);
}

String _formatGroupedAmount(
  double amount, {
  required int decimals,
  required bool negative,
}) {
  final fixed = amount.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final groupedInt = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  if (decimals == 0 || parts.length == 1) {
    return negative ? '-$groupedInt' : groupedInt;
  }
  final formatted = '$groupedInt.${parts[1]}';
  return negative ? '-$formatted' : formatted;
}
