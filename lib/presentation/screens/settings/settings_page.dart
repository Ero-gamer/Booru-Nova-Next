import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _SettingEntry {
  const _SettingEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

class _Section {
  const _Section(this.title, this.entries);
  final String title;
  final List<_SettingEntry> entries;
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 语言切换后整树重建，这里每次 build 重新取文案
    final sections = [
      _Section(T.sectionGeneral, [
        _SettingEntry(icon: Icons.palette_outlined, title: T.appearance, subtitle: T.appearanceSub, route: '/settings/appearance'),
        _SettingEntry(icon: Icons.language_outlined, title: T.language, subtitle: T.languageSub, route: '/settings/language'),
      ]),
      _Section(T.sectionBrowsing, [
        _SettingEntry(icon: Icons.image_outlined, title: T.viewerEntry, subtitle: T.viewerEntrySub, route: '/settings/viewer'),
        _SettingEntry(icon: Icons.gesture_outlined, title: T.gestures, subtitle: T.gesturesSub, route: '/settings/gestures'),
        _SettingEntry(icon: Icons.search_outlined, title: T.searchEntry, subtitle: T.searchEntrySub, route: '/settings/search'),
        _SettingEntry(icon: Icons.history_outlined, title: T.searchHistoryEntry, subtitle: T.searchHistoryEntrySub, route: '/search-history'),
      ]),
      _Section(T.sectionData, [
        _SettingEntry(icon: Icons.download_outlined, title: T.downloadEntry, subtitle: T.downloadEntrySub, route: '/settings/download'),
        _SettingEntry(icon: Icons.storage_outlined, title: T.dataAndStorage, subtitle: T.dataAndStorageSub, route: '/settings/data'),
        _SettingEntry(icon: Icons.backup_outlined, title: T.backup, subtitle: T.backupSub, route: '/settings/backup'),
      ]),
      _Section(T.sectionServer, [
        _SettingEntry(icon: Icons.dns_outlined, title: T.serverManage, subtitle: T.serverManageSub, route: '/servers'),
        _SettingEntry(icon: Icons.block_outlined, title: T.blacklist, subtitle: T.blacklistSub, route: '/blacklist'),
        _SettingEntry(icon: Icons.dns, title: T.hosts, subtitle: T.hostsEntrySub, route: '/settings/hosts'),
      ]),
      _Section(T.sectionOther, [
        _SettingEntry(icon: Icons.shield_outlined, title: T.privacyTitle, subtitle: T.privacyEntrySub, route: '/settings/privacy'),
        _SettingEntry(icon: Icons.info_outline, title: T.about, subtitle: T.aboutSub, route: '/settings/about'),
      ]),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(T.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final section in sections) ...[
            SectionHeader(title: section.title),
            for (final entry in section.entries)
              ListTile(
                leading: Icon(entry.icon),
                title: Text(entry.title),
                subtitle: Text(entry.subtitle, style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.push(entry.route),
              ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
