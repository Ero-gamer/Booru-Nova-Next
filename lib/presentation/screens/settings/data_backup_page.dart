import 'dart:convert';
import 'dart:io';

import 'package:boorunova/data/repository/booru/entity/post.dart';
import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/data/repository/favorites/user_favorite_repo.dart';
import 'package:boorunova/data/repository/search_history/search_history_repo.dart';
import 'package:boorunova/data/repository/server/entity/server.dart';
import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/data/repository/tags_blocker/entity/booru_tag.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/provider/tags_blocker_state.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart' show SectionHeader;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class DataBackupPage extends ConsumerWidget {
  const DataBackupPage({super.key});

  Future<String> _exportData(WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final servers = ref.read(userServerRepoProvider).getAll();
    final blocked = ref.read(tagsBlockerRepoProvider).getAll();
    final favorites = ref.read(userFavoritesRepoProvider).getAll();
    final history = ref.read(searchHistoryRepoProvider).getAll();
    final downloads = ref.read(userDownloadsRepoProvider).getAll();

    final data = {
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'data': {
        'settings': settings.toJson(),
        'serverCount': servers.length,
        // 导出不含凭据（apiKey/login），见 BooruServer.toBackupJson。
        'servers': servers.map((s) => s.toBackupJson()).toList(),
        'blockedTags': blocked.values.map((t) => t.toJson()).toList(),
        'favorites': favorites.map((f) => f.toJson()).toList(),
        'searchHistory': history,
        'downloads': downloads.map((d) => d.toJson()).toList(),
      },
    };

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/boorunova_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    try {
      final file = File(result.files.first.path!);
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;

      // 版本校验：拒绝高版本备份，避免用新数据误写旧结构
      final version = (json['version'] as num?)?.toInt() ?? 1;
      const supportedVersion = 1;
      if (version > supportedVersion) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(T.isEn
                ? 'Backup is newer than this app supports (v$supportedVersion)'
                : '备份版本过新，当前应用最高支持 v$supportedVersion'),
          ));
        }
        return;
      }

      // Import servers（逐条容错：坏记录跳过，不整体中止）
      if (data['servers'] != null) {
        final list = data['servers'] as List;
        final repo = ref.read(userServerRepoProvider);
        final existing = repo.getAll().toList();
        for (final item in list) {
          try {
            final server =
                BooruServer.fromJson(Map<String, dynamic>.from(item as Map));
            if (!existing.any((e) => e.id == server.id)) {
              await repo.save(server);
            }
          } catch (_) {
            // 跳过损坏的单条服务器记录
          }
        }
        ref.invalidate(userServerRepoProvider);
      }

      // Import blocked tags
      if (data['blockedTags'] != null) {
        final list = data['blockedTags'] as List;
        final blocker = ref.read(tagsBlockerRepoProvider);
        for (final item in list) {
          final tag = BooruTag.fromJson(Map<String, dynamic>.from(item as Map));
          await blocker.push(tag);
        }
        ref.invalidate(tagsBlockerRepoProvider);
        ref.invalidate(tagsBlockerStateProvider);
      }

      // Import favorites
      if (data['favorites'] != null) {
        final list = data['favorites'] as List;
        final repo = ref.read(userFavoritesRepoProvider);
        final all = [...repo.getAll()];
        for (final item in list) {
          final post = BooruPost.fromJson(Map<String, dynamic>.from(item as Map));
          final key = '${post.serverId}|${post.id}';
          if (!all.any((p) => '${p.serverId}|${p.id}' == key)) {
            all.add(post);
          }
        }
        await repo.saveAll(all);
        ref.invalidate(userFavoritesRepoProvider);
      }

      // Import search history
      if (data['searchHistory'] != null) {
        final list = (data['searchHistory'] as List).cast<String>();
        final repo = ref.read(searchHistoryRepoProvider);
        await repo.replaceAll(list);
        ref.invalidate(searchHistoryRepoProvider);
      }

      // Import downloads
      if (data['downloads'] != null) {
        final list = data['downloads'] as List;
        final repo = ref.read(userDownloadsRepoProvider);
        final all = [...repo.getAll()];
        for (final item in list) {
          final entry = DownloadEntry.fromJson(Map<String, dynamic>.from(item as Map));
          if (!all.any((d) => d.postId == entry.postId)) {
            all.add(entry);
          }
        }
        await repo.saveAll(all);
        ref.invalidate(userDownloadsRepoProvider);
      }

      // Import settings
      if (data['settings'] != null) {
        await ref
            .read(settingsProvider.notifier)
            .restore(AppSettings.fromJson(Map<String, dynamic>.from(data['settings'] as Map)));
        ref.invalidate(settingsProvider);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(T.backupImported)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${T.importFailed}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(userServerRepoProvider).getAll();
    final blocked = ref.watch(tagsBlockerRepoProvider).getAll();
    final favorites = ref.watch(userFavoritesRepoProvider).getAll().length;
    final history = ref.watch(searchHistoryRepoProvider).getAll().length;
    final downloads = ref.watch(userDownloadsRepoProvider).getAll().length;

    return Scaffold(
      appBar: AppBar(title: Text(T.backupTitle)),
      body: ListView(children: [
        SectionHeader(title: T.backupContentHeader),
        ListTile(title: Text(T.servers), trailing: Text('${servers.length}${T.serversCountUnit}')),
        ListTile(title: Text(T.blacklist), trailing: Text('${blocked.length}${T.recordsUnit}')),
        ListTile(title: Text(T.favorites), trailing: Text('$favorites${T.recordsUnit}')),
        ListTile(title: Text(T.searchHistoryEntry), trailing: Text('$history${T.recordsUnit}')),
        ListTile(title: Text(T.downloadHistory), trailing: Text('$downloads${T.recordsUnit}')),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: Text(T.exportBackup),
          subtitle: Text(T.exportBackupSub),
          onTap: () async {
            try {
              final path = await _exportData(ref);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${T.exportedTo}$path')));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${T.exportFailed}: $e')));
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: Text(T.importBackup),
          subtitle: Text(T.importBackupSub),
          onTap: () => _importData(context, ref),
        ),
      ]),
    );
  }
}
