import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import 'weekly_report.dart';

/// The week at a glance for the parents: each child's stars day by day
/// against last week, and when bedtime started.
class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  String? _child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final preferences = scope.preferences;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.weeklyReport)),
      body: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) {
          final children = preferences.children;
          final child = children.any((c) => c.id == _child)
              ? _child!
              : preferences.activeChildId;
          final report = WeeklyReport.of(
            stars: preferences.starsOf(child),
            bedtimes: preferences.bedtimesOf(child),
            now: scope.clock(),
          );
          return ListView(
            padding: context.pageInsets(),
            children: [
              Text(l10n.weeklyReportDescription,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (children.length > 1) ...[
                Wrap(
                  spacing: 6,
                  children: [
                    for (final c in children)
                      ChoiceChip(
                        label: Text(c.name),
                        selected: child == c.id,
                        onSelected: (_) => setState(() => _child = c.id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              _StarsCard(report: report),
              const SizedBox(height: 12),
              _BedtimeCard(report: report),
            ],
          );
        },
      ),
    );
  }
}

class _StarsCard extends StatelessWidget {
  const _StarsCard({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final most = report.starsPerDay.fold(1, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reportStars(report.starsThisWeek),
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.reportLastWeek(report.starsLastWeek),
                style: theme.textTheme.bodyMedium),
            Text(l10n.reportRoutines(report.routinesDone),
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var day = 0; day < 7; day++)
                    Expanded(
                      child: Semantics(
                        label: '${localizations.narrowWeekdays[(day + 1) % 7]}'
                            ' ${report.starsPerDay[day]}',
                        excludeSemantics: true,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${report.starsPerDay[day]}',
                                style: theme.textTheme.labelSmall),
                            const SizedBox(height: 2),
                            Container(
                              height: 4 + 68 * report.starsPerDay[day] / most,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: report.starsPerDay[day] == 0
                                    ? theme.colorScheme.surfaceContainerHighest
                                    : Colors.amber,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(localizations.narrowWeekdays[(day + 1) % 7],
                                style: theme.textTheme.labelMedium),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BedtimeCard extends StatelessWidget {
  const _BedtimeCard({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    String time(int minutes) => localizations.formatTimeOfDay(
        TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        alwaysUse24HourFormat: h24);
    final average = report.bedtimeAverage;
    final range = report.bedtimeRange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bedtime_outlined),
                const SizedBox(width: 8),
                Text(l10n.reportBedtime, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            if (average == null || range == null)
              Text(l10n.reportNoBedtimes, style: theme.textTheme.bodyMedium)
            else ...[
              Text(l10n.reportBedtimeAverage(time(average)),
                  style: theme.textTheme.titleMedium),
              if (range.earliest != range.latest)
                Text(
                    l10n.reportBedtimeRange(
                        time(range.earliest), time(range.latest)),
                    style: theme.textTheme.bodyMedium),
              Text(l10n.reportBedtimeNights(report.bedtimes.length),
                  style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
