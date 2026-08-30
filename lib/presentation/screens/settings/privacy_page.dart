import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(T.privacyTitle)),
      body: ListView(children: [
        SectionHeader(title: T.sectionDataManage),
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(T.clearSearchHistory),
          subtitle: Text(T.clearSearchHistorySub),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(T.clearSearchHistory),
                content: Text(T.clearSearchHistorySub),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(T.cancel)),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(T.clear)),
                ],
              ),
            );
            if ((confirmed ?? false) && context.mounted) {
              await ref.read(searchHistoryRepoProvider).clear();
              ref.invalidate(searchHistoryRepoProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(T.searchHistoryCleared)));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.visibility_outlined),
          title: Text(T.clearViewHistory),
          subtitle: Text(T.clearViewHistorySub),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(T.clearHistoryTitle),
                content: Text(T.clearHistoryContent),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(T.cancel)),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(T.clear)),
                ],
              ),
            );
            if ((confirmed ?? false) && context.mounted) {
              await ref.read(userHistoryRepoProvider).clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(T.viewHistoryCleared)));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.download_done_outlined),
          title: Text(T.clearDownloadRecords),
          subtitle: Text(T.clearDownloadRecordsSub),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(T.clearDownloadHistoryTitle),
                content: Text(T.clearDownloadHistoryContent),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(T.cancel)),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(T.clear)),
                ],
              ),
            );
            if ((confirmed ?? false) && context.mounted) {
              await ref.read(userDownloadsRepoProvider).clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(T.downloadRecordsCleared)));
              }
            }
          },
        ),
        SectionHeader(title: T.sectionPrivacyNote),
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: Text(T.dataCollection),
          subtitle: Text(T.dataCollectionSub),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(T.networkRequests),
          subtitle: Text(T.networkRequestsSub),
        ),
      ]),
    );
  }
}
