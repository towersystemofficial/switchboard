import 'package:flutter/material.dart';

enum DateRangeOption { day, week, twoWeeks, month, threeMonths, year, allTime, custom }

const Map<DateRangeOption, String> dateRangeLabels = {
  DateRangeOption.day: 'Past day',
  DateRangeOption.week: 'Past week',
  DateRangeOption.twoWeeks: 'Past 2 weeks',
  DateRangeOption.month: 'Past month',
  DateRangeOption.threeMonths: 'Past 3 months',
  DateRangeOption.year: 'Past year',
  DateRangeOption.allTime: 'All time',
  DateRangeOption.custom: 'Custom range...',
};

/// Resolves a [DateRangeOption] (plus an optional custom [range]) into
/// concrete start/end bounds. Both null means "all time" -- callers should
/// treat that as "no lower/upper bound," and pick their own fallback anchor
/// if they need one for rendering (e.g. a timeline needs a concrete start).
class ResolvedDateRange {
  final DateTime? start;
  final DateTime? end;
  const ResolvedDateRange(this.start, this.end);
}

ResolvedDateRange resolveDateRange(DateRangeOption option, DateTimeRange? customRange) {
  final now = DateTime.now();
  switch (option) {
    case DateRangeOption.day:
      return ResolvedDateRange(now.subtract(const Duration(days: 1)), null);
    case DateRangeOption.week:
      return ResolvedDateRange(now.subtract(const Duration(days: 7)), null);
    case DateRangeOption.twoWeeks:
      return ResolvedDateRange(now.subtract(const Duration(days: 14)), null);
    case DateRangeOption.month:
      return ResolvedDateRange(now.subtract(const Duration(days: 30)), null);
    case DateRangeOption.threeMonths:
      return ResolvedDateRange(now.subtract(const Duration(days: 90)), null);
    case DateRangeOption.year:
      return ResolvedDateRange(now.subtract(const Duration(days: 365)), null);
    case DateRangeOption.allTime:
      return const ResolvedDateRange(null, null);
    case DateRangeOption.custom:
      return ResolvedDateRange(customRange?.start, customRange?.end);
  }
}