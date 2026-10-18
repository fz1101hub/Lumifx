import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import 'ready_links.dart';

/// Explains `lumifx://` links and offers ready-made ones to copy into
/// Siri Shortcuts or an Android automation.
class LinksScreen extends StatelessWidget {
  const LinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final links = readyLinks(scope, l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.linksTitle)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.linksDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final (title, link) in links)
            Card(
              child: ListTile(
                title: Text(title),
                subtitle: SelectableText(link),
                trailing: IconButton(
                  tooltip: l10n.copyLink,
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                            SnackBar(content: Text(l10n.linkCopied)));
                    }
                  },
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(l10n.linksNote, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
