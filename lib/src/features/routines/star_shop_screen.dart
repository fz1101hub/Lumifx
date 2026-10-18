import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import '../kids/kids_mode.dart';
import 'child_picker.dart';
import 'star_shop.dart';

/// The star shop: the stars a child earned with their routines buy the
/// rewards a grown-up set; a grown-up confirms each one.
class StarShopScreen extends StatelessWidget {
  const StarShopScreen({super.key});

  Future<void> _get(BuildContext context, Reward reward) async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!await GrownUpGate.ask(context, title: l10n.starShopGrownUp)) {
      return;
    }
    final preferences = scope.preferences;
    if (!preferences.spendStars(preferences.activeChildId, reward.cost)) {
      return;
    }
    unawaited(HapticFeedback.heavyImpact());
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.starShopEnjoy(reward.name))));
    final playback = scope.playback;
    await playback.switchEffect(rewardParty(l10n.starShop));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  Future<void> _add(BuildContext context) async {
    final l10n = context.l10n;
    final preferences = AppScope.of(context).preferences;
    if (!await GrownUpGate.ask(context, title: l10n.starShopGrownUp) ||
        !context.mounted) {
      return;
    }
    final reward = await showDialog<Reward>(
      context: context,
      builder: (_) => const _RewardDialog(),
    );
    if (reward != null) {
      await preferences.addReward(reward.name, reward.cost, reward.icon);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preferences = AppScope.of(context).preferences;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.starShop)),
      body: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) {
          final child = preferences.activeChildId;
          final balance = preferences.starBalance(child);
          return ListView(
            padding: context.pageInsets(),
            children: [
              const ChildPicker(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.star, size: 40, color: Colors.amber.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(l10n.starShopBalance(balance),
                          style: theme.textTheme.headlineSmall),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (preferences.rewards.isEmpty)
                Text(l10n.starShopEmpty, style: theme.textTheme.bodyMedium),
              for (final reward in preferences.rewards)
                Card(
                  child: ListTile(
                    minVerticalPadding: 12,
                    leading: Icon(rewardIcons[reward.icon], size: 36),
                    title:
                        Text(reward.name, style: theme.textTheme.titleMedium),
                    subtitle: Text(balance >= reward.cost
                        ? '★ ${reward.cost}'
                        : '★ ${reward.cost} · '
                            '${l10n.starShopNeedMore(reward.cost - balance)}'),
                    trailing: FilledButton(
                      onPressed: balance >= reward.cost
                          ? () => _get(context, reward)
                          : null,
                      child: Text(l10n.starShopGet),
                    ),
                    onLongPress: () async {
                      if (await GrownUpGate.ask(context,
                          title: l10n.starShopGrownUp)) {
                        await preferences.removeReward(reward.id);
                      }
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: preferences.rewards.length < Reward.maxRewards
                      ? () => _add(context)
                      : null,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.starShopAdd),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.starShopRemoveHint, style: theme.textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }
}

/// A new reward: its name, picture and cost.
class _RewardDialog extends StatefulWidget {
  const _RewardDialog();

  @override
  State<_RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<_RewardDialog> {
  final _name = TextEditingController();
  var _cost = 5;
  var _icon = 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.starShopAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: Reward.maxName,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.starShopRewardName),
              onChanged: (_) => setState(() {}),
            ),
            Wrap(
              spacing: 4,
              children: [
                for (final (i, icon) in rewardIcons.indexed)
                  IconButton(
                    isSelected: _icon == i,
                    icon: Icon(icon),
                    onPressed: () => setState(() => _icon = i),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.starShopCost, style: theme.textTheme.titleSmall),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _cost > 1 ? () => setState(() => _cost--) : null,
                ),
                Text('★ $_cost', style: theme.textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _cost < Reward.maxCost
                      ? () => setState(() => _cost++)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(Reward(
                    id: '',
                    name: _name.text,
                    cost: _cost,
                    icon: _icon,
                  )),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
