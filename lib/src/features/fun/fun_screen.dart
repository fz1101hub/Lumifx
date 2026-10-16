import 'package:flutter/material.dart';

import '../common/app_text.dart';
import '../common/layout.dart';
import 'birthday_screen.dart';

/// Parties and games played with the lights.
class FunScreen extends StatelessWidget {
  const FunScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget entry(
      IconData icon,
      String title,
      String subtitle,
      Widget Function() screen,
    ) =>
        Card(
          child: ListTile(
            minVerticalPadding: 16,
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => screen()),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fun)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          entry(Icons.cake_outlined, l10n.birthday, l10n.birthdaySubtitle,
              () => const BirthdayScreen()),
        ],
      ),
    );
  }
}
