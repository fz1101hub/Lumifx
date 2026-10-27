import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/routines/weekly_report.dart';

void main() {
  // Wednesday.
  final now = DateTime(2026, 10, 28, 9);

  test('stars are counted day by day against last week', () {
    final report = WeeklyReport.of(
      stars: {
        '2026-10-26:morning',
        '2026-10-26:evening',
        '2026-10-28:morning',
        '2026-10-27:toothfairy',
        '2026-10-25:evening',
        '2026-10-19:morning',
        '2026-10-18:morning',
        'not a star',
      },
      bedtimes: const [],
      now: now,
    );
    expect(report.starsPerDay, [2, 1, 1, 0, 0, 0, 0]);
    expect(report.starsThisWeek, 4);
    expect(report.starsLastWeek, 2);
    expect(report.routinesDone, 3);
    expect(report.bedtimeAverage, isNull);
    expect(report.bedtimeRange, isNull);
  });

  test('bedtimes past midnight count for the evening before', () {
    final report = WeeklyReport.of(
      stars: const {},
      bedtimes: [
        DateTime(2026, 10, 25, 21),
        DateTime(2026, 10, 26, 23, 30),
        DateTime(2026, 10, 28, 0, 30),
      ],
      now: now,
    );
    expect(report.bedtimes, hasLength(2), reason: 'Sunday is last week');
    expect(report.bedtimeAverage, 0, reason: 'midnight, not noon');
    expect(report.bedtimeRange, (earliest: 23 * 60 + 30, latest: 30));
  });

  test('the week starts on Monday, also across a clock change', () {
    expect(WeeklyReport.mondayOf(DateTime(2026, 11, 1, 22)),
        DateTime(2026, 10, 26));
    final report = WeeklyReport.of(
      stars: {'2026-11-01:evening'},
      bedtimes: const [],
      now: DateTime(2026, 11, 1, 22),
    );
    expect(report.starsPerDay.last, 1);
  });
}
