import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/booru/page_state.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchHistoryPage extends ConsumerWidget {
  const SearchHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryRepoProvider).getAll();
    return Scaffold(
      appBar: AppBar(
        title: Text(T.searchHistoryTitle),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: T.clearSearchHistoryTip,
              onPressed: () async {
                await ref.read(searchHistoryRepoProvider).clear();
                ref.invalidate(searchHistoryRepoProvider);
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.history,
                title: T.noSearchHistory,
                hint: T.searchHistoryHint,
              ),
            )
          : ListView.separated(
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.history, size: 20),
                title: Text(history[i], style: const TextStyle(fontSize: 14)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: T.deleteAction,
                  onPressed: () async {
                    await ref.read(searchHistoryRepoProvider).remove(history[i]);
                    ref.invalidate(searchHistoryRepoProvider);
                  },
                ),
                onTap: () {
                  ref.read(booruPageStateProvider.notifier).search(history[i]);
                  context.go('/');
                },
              ),
            ),
    );
  }
}
