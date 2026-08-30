import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(settingsProvider).language;
    final theme = Theme.of(context);

    Widget tile(String code, IconData icon, String name, String subtitle) {
      final selected = language.startsWith(code);
      return ListTile(
        leading: Icon(icon,
            color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
        title: Text(name),
        subtitle: Text(subtitle),
        trailing: selected
            ? Icon(Icons.check, color: theme.colorScheme.primary)
            : null,
        onTap: () {
          ref.read(settingsProvider.notifier).setLanguage(code);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(T.language)),
      body: ListView(children: [
        tile('zh', Icons.language, T.langZhName,
            T.isEn ? 'Chinese (Simplified)' : T.currentLanguage),
        tile('en', Icons.abc, T.langEnName,
            T.isEn ? T.currentLanguage : 'English (US)'),
      ]),
    );
  }
}
