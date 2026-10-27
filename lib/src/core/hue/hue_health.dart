/// What can be wrong with a light, worst first.
enum LightIssue {
  /// The bridge cannot reach it: often switched off at the wall.
  unreachable,

  /// It answers, but the radio link is poor.
  weakSignal,

  /// Newer firmware is ready to install.
  updateReady,
}

/// How one light is doing, as the bridge sees it.
class HueLightHealth {
  const HueLightHealth({
    required this.name,
    required this.issues,
    this.model,
    this.firmware,
  });

  final String name;

  /// The product name ("Hue color lamp").
  final String? model;
  final String? firmware;
  final Set<LightIssue> issues;

  bool get isFine => issues.isEmpty;

  /// The worst issue, or null when it is fine.
  LightIssue? get worst =>
      isFine ? null : LightIssue.values.firstWhere(issues.contains);
}

/// The lights' health and whether the bridge itself has an update.
class HueHealthReport {
  const HueHealthReport({required this.lights, this.bridgeUpdateReady = false});

  /// Lights with an issue first (worst first), then by name.
  final List<HueLightHealth> lights;
  final bool bridgeUpdateReady;

  int get problems => lights.where((l) => !l.isFine).length;

  /// Orders [lights] for the report.
  static List<HueLightHealth> sorted(Iterable<HueLightHealth> lights) =>
      [...lights]..sort((a, b) {
          final byIssue = (a.worst?.index ?? LightIssue.values.length)
              .compareTo(b.worst?.index ?? LightIssue.values.length);
          return byIssue != 0
              ? byIssue
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
}
