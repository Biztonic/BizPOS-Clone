/// Shared date utility extensions used across feature modules.
extension DateTimeExtensions on DateTime {
  /// Returns the date portion as 'YYYY-MM-DD' string.
  String toDateString() {
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  /// Returns 'YYYY-MM' format for monthly grouping.
  String toYearMonth() {
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
  }

  /// Returns true if this date is today.
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Returns true if this date is yesterday.
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  /// Returns true if this date is within the current month.
  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// Returns the start of the day (00:00:00).
  DateTime get startOfDay => DateTime(year, month, day);

  /// Returns the end of the day (23:59:59.999).
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// Returns the start of the month.
  DateTime get startOfMonth => DateTime(year, month, 1);

  /// Returns the end of the month.
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59, 999);
}
