import 'package:flutter/material.dart';

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// A reward a grown-up set in the star shop, and the stars it costs.
class Reward {
  const Reward({
    required this.id,
    required this.name,
    required this.cost,
    this.icon = 0,
  });

  final String id;
  final String name;
  final int cost;

  /// Index into [rewardIcons].
  final int icon;

  static const maxRewards = 20;
  static const maxCost = 99;
  static const maxName = 40;

  Map<String, Object?> toJson() =>
      {'id': id, 'name': name, 'cost': cost, 'icon': icon};

  static Reward? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    final name = json['name'];
    final cost = json['cost'];
    final icon = json['icon'];
    if (id is! String ||
        name is! String ||
        name.trim().isEmpty ||
        cost is! int ||
        cost < 1 ||
        cost > maxCost) {
      return null;
    }
    final trimmed = name.trim();
    return Reward(
      id: id,
      name: trimmed.length > maxName ? trimmed.substring(0, maxName) : trimmed,
      cost: cost,
      icon: icon is int && icon >= 0 && icon < rewardIcons.length ? icon : 0,
    );
  }
}

/// Pictures for the rewards.
const rewardIcons = [
  Icons.icecream_outlined,
  Icons.toys_outlined,
  Icons.movie_outlined,
  Icons.park_outlined,
  Icons.menu_book_outlined,
  Icons.sports_esports_outlined,
  Icons.cake_outlined,
  Icons.bedtime_outlined,
];

const _partyId = '${LightingEffect.generatedPrefix}starshop';

/// A reward bought: gold and confetti of light for a few seconds.
LightingEffect rewardParty(String name) => LightingEffect(
      id: _partyId,
      name: name,
      kind: EffectKind.story,
      isLooping: false,
      loopDuration: const Duration(seconds: 6),
      events: const [
        EffectEvent(
          at: Duration.zero,
          duration: Duration(seconds: 6),
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': <String>['#FFC94D', '#FFE7A3', '#FF9F43'],
            'brightnessMin': 0.5,
            'brightnessMax': 0.9,
            'speed': 0.2,
          },
        ),
        EffectEvent(
          at: Duration(milliseconds: 200),
          duration: Duration(seconds: 5),
          type: EffectEventTypes.surprise,
          parameters: {'color': '#FFFFFF', 'count': 8, 'brightness': 1.0},
        ),
      ],
    );

bool isRewardParty(LightingEffect effect) => effect.id == _partyId;
