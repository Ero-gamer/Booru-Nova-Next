import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GesturesPage extends ConsumerWidget {
  const GesturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(T.gestures)),
      body: ListView(children: [
        SectionHeader(title: T.sectionViewer),
        _tile(T.swipeDownAction, s.swipeDownAction, {'close': T.actionClose, 'detail': T.actionDetail}, n.setSwipeDownAction, s.swipeDownAction),
        _tile(T.tapAction, s.tapAction, {'detail': T.actionDetail, 'none': T.actionNone}, n.setTapAction, s.tapAction),
        _tile(T.doubleTapAction, s.doubleTapAction, {'zoom': T.actionZoom, 'fav': T.actionFav}, n.setDoubleTapAction, s.doubleTapAction),
        _tile(T.longPressAction, s.longPressAction, {'fav': T.actionFav, 'none': T.actionNone}, n.setLongPressAction, s.longPressAction),
      ]),
    );
  }

  Widget _tile(String title, String current, Map<String, String> labels,
      void Function(String) onChanged, String value) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(labels[value] ?? value, style: const TextStyle(fontSize: 12)),
      trailing: DropdownButton<String>(
        value: current, underline: const SizedBox(),
        items: labels.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }
}
