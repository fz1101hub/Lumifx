import 'package:flutter/material.dart';

import '../common/app_text.dart';
import 'kid_routine.dart';

/// A step a grown-up made for the family's routines ("feed the cat").
class CustomStep implements RoutineItem {
  const CustomStep({
    required this.id,
    required this.name,
    this.iconIndex = 0,
    this.color = '#7CFF6B',
  });

  final String id;
  final String name;

  /// Index into [customStepIcons].
  final int iconIndex;

  @override
  final String color;

  static const maxSteps = 12;
  static const maxName = 30;

  @override
  String get key => 'custom:$id';

  @override
  IconData get icon => customStepIcons[iconIndex];

  @override
  String label(AppLocalizations l10n) => name;

  Map<String, Object?> toJson() =>
      {'id': id, 'name': name, 'icon': iconIndex, 'color': color};

  static CustomStep? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    final name = json['name'];
    final icon = json['icon'];
    final color = json['color'];
    if (id is! String || id.isEmpty || name is! String || name.trim().isEmpty) {
      return null;
    }
    final trimmed = name.trim();
    return CustomStep(
      id: id,
      name: trimmed.length > maxName ? trimmed.substring(0, maxName) : trimmed,
      iconIndex:
          icon is int && icon >= 0 && icon < customStepIcons.length ? icon : 0,
      color: color is String && customStepColors.contains(color)
          ? color
          : customStepColors.first,
    );
  }

  @override
  bool operator ==(Object other) => other is CustomStep && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Pictures for the steps a grown-up makes.
const customStepIcons = [
  Icons.pets_outlined,
  Icons.medication_outlined,
  Icons.local_drink_outlined,
  Icons.local_florist_outlined,
  Icons.music_note_outlined,
  Icons.school_outlined,
  Icons.cleaning_services_outlined,
  Icons.favorite_outline,
  Icons.directions_bike_outlined,
  Icons.star_outline,
];

const customStepColors = [
  '#7CFF6B', '#FFB347', '#7FD3FF', '#FF8FAB', '#C3A6FF', '#FFE29A', //
];
