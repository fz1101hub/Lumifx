import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../bridge/bridge_setup_screen.dart';
import '../common/app_text.dart';

/// Three pages on the very first launch: what LumiFX does, connecting the
/// Hue Bridge, and trying it without one. Skippable at any time.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() {
    unawaited(AppScope.of(context).preferences.setOnboardingDone());
    Navigator.of(context).pop();
  }

  void _next() => _pages.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  Future<void> _connect() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BridgeSetupScreen()),
    );
    if (!mounted) {
      return;
    }
    if (AppScope.of(context).bridge.credentials != null) {
      _finish();
    } else {
      _next();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pages = [
      _Page(
        icon: Icons.auto_awesome,
        title: l10n.onboardingWelcomeTitle,
        body: l10n.onboardingWelcomeBody,
        actions: [
          FilledButton(onPressed: _next, child: Text(l10n.next)),
        ],
      ),
      _Page(
        icon: Icons.lightbulb_outline,
        title: l10n.onboardingBridgeTitle,
        body: l10n.onboardingBridgeBody,
        actions: [
          FilledButton(onPressed: _connect, child: Text(l10n.connectNow)),
          TextButton(onPressed: _next, child: Text(l10n.later)),
        ],
      ),
      _Page(
        icon: Icons.visibility_outlined,
        title: l10n.onboardingPreviewTitle,
        body: l10n.onboardingPreviewBody,
        actions: [
          FilledButton(onPressed: _finish, child: Text(l10n.getStarted)),
        ],
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          if (_page < pages.length - 1)
            TextButton(onPressed: _finish, child: Text(l10n.skip)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (page) => setState(() => _page = page),
                children: pages,
              ),
            ),
            Semantics(
              label: l10n.pageOf(_page + 1, pages.length),
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      width: i == _page ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == _page
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              for (final action in actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(width: double.infinity, child: action),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
