import 'package:intl/intl.dart';

/// Postgres `date` columns are exchanged as plain `YYYY-MM-DD` strings.
String toDateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime parseDate(String value) {
  final parts = value.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today" / "Yesterday" / "Mon, 14 Jul" — with the year once it's not this one.
String friendlyDate(DateTime date) {
  final t = today();
  if (isSameDay(date, t)) return 'Today';
  if (isSameDay(date, t.subtract(const Duration(days: 1)))) return 'Yesterday';
  final pattern = date.year == t.year ? 'EEE, d MMM' : 'EEE, d MMM yyyy';
  return DateFormat(pattern).format(date);
}

/// Drops the trailing `.0` so 40 kg doesn't render as "40.0 kg".
String formatWeight(double kg) {
  final rounded = (kg * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

String plural(int count, String singular, [String? pluralForm]) =>
    count == 1 ? '$count $singular' : '$count ${pluralForm ?? '${singular}s'}';
