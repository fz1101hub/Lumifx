import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import 'child.dart';

/// The children's profiles: one chip each to choose whose routines and
/// stars show, a chip to add a child and a button to rename or remove.
class ChildPicker extends StatelessWidget {
  const ChildPicker({super.key});

  static Future<String?> _askName(BuildContext context, String title,
          [String initial = '']) =>
      showDialog<String>(
        context: context,
        builder: (_) => _NameDialog(title: title, initial: initial),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preferences = AppScope.of(context).preferences;
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) {
        final children = preferences.children;
        final active = preferences.activeChildId;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final child in children)
              ChoiceChip(
                avatar: CircleAvatar(
                  child: Text(child.name.characters.first.toUpperCase()),
                ),
                label: Text(child.name),
                selected: child.id == active,
                onSelected: (_) => preferences.setActiveChild(child.id),
              ),
            if (children.length < Child.maxChildren)
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_1),
                label: Text(l10n.childAdd),
                onPressed: () async {
                  final name = await _askName(context, l10n.childAdd);
                  if (name != null && name.trim().isNotEmpty) {
                    await preferences.addChild(name);
                  }
                },
              ),
            if (children.isNotEmpty)
              IconButton(
                tooltip: l10n.childrenEdit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _ChildrenDialog(),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Rename or remove the children.
class _ChildrenDialog extends StatelessWidget {
  const _ChildrenDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preferences = AppScope.of(context).preferences;
    return AlertDialog(
      title: Text(l10n.childrenEdit),
      content: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final child in preferences.children)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(child.name.characters.first.toUpperCase()),
                  ),
                  title: Text(child.name),
                  onTap: () async {
                    final name = await ChildPicker._askName(
                        context, l10n.childRename, child.name);
                    if (name != null && name.trim().isNotEmpty) {
                      await preferences.renameChild(child.id, name);
                    }
                  },
                  trailing: IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final sure = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: Text(l10n.childRemoveConfirm(child.name)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(l10n.delete),
                            ),
                          ],
                        ),
                      );
                      if (sure == true) {
                        await preferences.removeChild(child.id);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: Child.maxName,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l10n.childName),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
