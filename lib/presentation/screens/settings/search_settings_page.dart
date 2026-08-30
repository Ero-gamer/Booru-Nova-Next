import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/booru/tag_suggestions.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart' show SectionHeader;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchSettingsPage extends ConsumerWidget {
  const SearchSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(tagSuggestionLimitProvider);
    return Scaffold(
      appBar: AppBar(title: Text(T.searchEntry)),
      body: ListView(children: [
        SectionHeader(title: T.sectionTagSuggest),
        ListTile(
          title: Text(T.suggestionCount),
          subtitle: Text('$limit${T.countUnit}'),
          trailing: SizedBox(
            width: 140,
            child: Slider(
              value: limit.toDouble(), min: 4, max: 20, divisions: 16,
              label: '$limit',
              onChanged: (v) => ref.read(tagSuggestionLimitProvider.notifier).state = v.round(),
            ),
          ),
        ),
      ]),
    );
  }
}
