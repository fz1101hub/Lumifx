import 'kid_routine.dart';

/// A week of a child's evenings and stars, for the parents: the stars of
/// this week (Monday to today) against last week's, day by day, and the
/// time bedtime started on the evenings it was recorded.
class WeeklyReport {
  const WeeklyReport({
    required this.starsPerDay,
    required this.starsLastWeek,
    required this.routinesDone,
    required this.bedtimes,
  });

  /// The report of [stars] (`yyyy-mm-dd:what` keys) and [bedtimes] for the
  /// week of [now].
  factory WeeklyReport.of({
    required Set<String> stars,
    required List<DateTime> bedtimes,
    required DateTime now,
  }) {
    final monday = mondayOf(now);
    final lastMonday = DateTime(monday.year, monday.month, monday.day - 7);
    final perDay = List.filled(7, 0);
    var lastWeek = 0;
    var routines = 0;
    final routineNames = {for (final r in KidRoutine.values) r.name};
    for (final key in stars) {
      final day = dayOfStar(key);
      if (day == null) {
        continue;
      }
      if (!day.isBefore(monday) && day.isBefore(_next(monday, 7))) {
        // Rounded, as a day across a clock change is 23 or 25 hours.
        perDay[(day.difference(monday).inHours + 12) ~/ 24]++;
        if (routineNames.contains(key.substring(11))) {
          routines++;
        }
      } else if (!day.isBefore(lastMonday) && day.isBefore(monday)) {
        lastWeek++;
      }
    }
    return WeeklyReport(
      starsPerDay: perDay,
      starsLastWeek: lastWeek,
      routinesDone: routines,
      bedtimes: [
        for (final at in bedtimes)
          if (!eveningOf(at).isBefore(monday) &&
              eveningOf(at).isBefore(_next(monday, 7)))
            at,
      ],
    );
  }

  /// Stars earned on each day of this week, Monday first.
  final List<int> starsPerDay;

  final int starsLastWeek;

  /// Morning and evening routines finished this week.
  final int routinesDone;

  /// When bedtime started on this week's evenings.
  final List<DateTime> bedtimes;

  int get starsThisWeek => starsPerDay.fold(0, (a, b) => a + b);

  /// Bedtime as minutes past noon, so that 23:30 and 00:15 sit side by
  /// side (the evening runs from noon to noon).
  static int minutesPastNoon(DateTime at) =>
      (at.hour * 60 + at.minute - 12 * 60) % (24 * 60);

  /// The average bedtime as minutes since midnight; null without any.
  int? get bedtimeAverage {
    if (bedtimes.isEmpty) {
      return null;
    }
    final total = bedtimes.fold(0, (sum, at) => sum + minutesPastNoon(at));
    return ((total / bedtimes.length).round() + 12 * 60) % (24 * 60);
  }

  /// The earliest and latest bedtime, as minutes since midnight.
  ({int earliest, int latest})? get bedtimeRange {
    if (bedtimes.isEmpty) {
      return null;
    }
    final past = [for (final at in bedtimes) minutesPastNoon(at)]..sort();
    int back(int m) => (m + 12 * 60) % (24 * 60);
    return (earliest: back(past.first), latest: back(past.last));
  }

  static DateTime mondayOf(DateTime now) =>
      DateTime(now.year, now.month, now.day - (now.weekday - 1));

  /// The evening [at] belongs to: past midnight still counts as the day
  /// before, up to noon.
  static DateTime eveningOf(DateTime at) =>
      DateTime(at.year, at.month, at.day - (at.hour < 12 ? 1 : 0));

  /// The day of a star key (`yyyy-mm-dd:...`), or null.
  static DateTime? dayOfStar(String key) {
    if (key.length < 11 || key[10] != ':') {
      return null;
    }
    final [year, month, day, ...] = [...key.substring(0, 10).split('-'), ''];
    final y = int.tryParse(year), m = int.tryParse(month);
    final d = int.tryParse(day);
    return y == null || m == null || d == null ? null : DateTime(y, m, d);
  }

  static DateTime _next(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);
}
