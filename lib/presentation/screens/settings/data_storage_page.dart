import 'dart:io';

import 'package:boorunova/data/repository/downloads/user_downloads_repo.dart';
import 'package:boorunova/data/repository/history/user_history_repo.dart';
import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart' show SectionHeader;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class DataStoragePage extends StatefulWidget {
  const DataStoragePage({super.key});
  @override
  State<DataStoragePage> createState() => _DataStoragePageState();
}

class _DataStoragePageState extends State<DataStoragePage> {
  String _cacheSize = '';

  @override
  void initState() {
    super.initState();
    _cacheSize = T.calculating;
    _calcCache();
  }

  Future<Directory?> _appTempDir() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<void> _calcCache() async {
    try {
      final temp = await _appTempDir();
      int size = 0;
      if (temp != null && temp.existsSync()) {
        await for (final e in temp.list()) {
          if (e is File) size += await e.length();
        }
      }
      setState(() => _cacheSize = '${(size / 1048576).toStringAsFixed(1)} MB');
    } catch (_) {
      setState(() => _cacheSize = T.unknown);
    }
  }

  Future<void> _clearCache() async {
    try {
      final temp = await _appTempDir();
      int count = 0;
      if (temp != null && temp.existsSync()) {
        await for (final e in temp.list()) {
          if (e is File) {
            await e.delete();
            count++;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${T.clearedCacheFiles}$count${T.tempFiles}')),
        );
        await _calcCache();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(T.dataAndStorage)),
      body: ListView(children: [
        SectionHeader(title: T.sectionCache),
        ListTile(
          leading: const Icon(Icons.storage),
          title: Text(T.cache),
          subtitle: _cacheSize == T.calculating
              ? Row(children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(T.calculating, style: Theme.of(context).textTheme.bodySmall),
                ])
              : Text(_cacheSize),
          trailing: TextButton(onPressed: _clearCache, child: Text(T.clearAction)),
        ),
        Consumer(
          builder: (context, ref, _) {
            final cache = PaintingBinding.instance.imageCache;
            final imgs = cache.currentSize;
            final imgBytes = cache.currentSizeBytes;
            final mb = (imgBytes / 1048576).toStringAsFixed(1);
            return ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(T.imageCache),
              subtitle: Text(T.isEn ? '$imgs images, $mb MB' : '$imgs 张, $mb MB'),
              trailing: TextButton(
                onPressed: () {
                  cache.clear();
                  cache.clearLiveImages();
                  clearDiskCachedImages();
                  setState(() {});
                },
                child: Text(T.clearAction),
              ),
            );
          },
        ),
        SectionHeader(title: T.sectionRecords),
        Consumer(
          builder: (context, ref, _) {
            final historyCount = ref.watch(userHistoryRepoProvider).count;
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(T.browsingHistory),
              subtitle: Text('$historyCount ${T.recordsUnit}'),
              trailing: TextButton(
                onPressed: () async {
                  await ref.read(userHistoryRepoProvider).clear();
                  ref.invalidate(userHistoryRepoProvider);
                },
                child: Text(T.clearAction),
              ),
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final downloadCount = ref.watch(userDownloadsRepoProvider).count;
            return ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(T.downloadHistory),
              subtitle: Text('$downloadCount ${T.recordsUnit}'),
              trailing: TextButton(
                onPressed: () async {
                  await ref.read(userDownloadsRepoProvider).clear();
                  ref.invalidate(userDownloadsRepoProvider);
                },
                child: Text(T.clearAction),
              ),
            );
          },
        ),
      ]),
    );
  }
}
