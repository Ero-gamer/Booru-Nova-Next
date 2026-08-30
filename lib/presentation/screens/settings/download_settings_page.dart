import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart' show SectionHeader;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class DownloadSettingsPage extends ConsumerStatefulWidget {
  const DownloadSettingsPage({super.key});
  @override
  ConsumerState<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends ConsumerState<DownloadSettingsPage> {
  String _defaultPath = '';

  @override
  void initState() {
    super.initState();
    _loadPath();
  }

  Future<void> _loadPath() async {
    final dir = await getTemporaryDirectory();
    if (mounted) setState(() => _defaultPath = dir.path);
  }

  Future<void> _pickPath() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      await ref.read(settingsProvider.notifier).setDownloadPath(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(T.downloadSettingsTitle)),
      body: ListView(children: [
        SectionHeader(title: T.sectionQuality),
        ListTile(
          title: Text(T.downloadQuality),
          trailing: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'sample', label: Text(T.qualitySample, style: const TextStyle(fontSize: 12))),
              ButtonSegment(value: 'original', label: Text(T.qualityOriginal, style: const TextStyle(fontSize: 12))),
            ],
            selected: {settings.downloadQuality},
            onSelectionChanged: (v) => ref.read(settingsProvider.notifier).setDownloadQuality(v.first),
          ),
        ),
        SectionHeader(title: T.sectionPath),
        ListTile(
          title: Text(T.downloadPath),
          subtitle: Text(
            settings.downloadPath.isNotEmpty
                ? settings.downloadPath
                : '${T.defaultPathPrefix}$_defaultPath',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: const Icon(Icons.folder_open),
          onTap: _pickPath,
        ),
        if (settings.downloadPath.isNotEmpty)
          ListTile(
            title: Text(T.resetDefaultPath),
            trailing: const Icon(Icons.restore),
            onTap: () => ref.read(settingsProvider.notifier).setDownloadPath(''),
          ),
      ]),
    );
  }
}
