import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final gridColumnsProvider = StateProvider<int>((ref) => 3);

/// 首页底部悬浮搜索栏：自身透明，玻璃质感由外层 GlassContainer 提供。
class HomeSearchBar extends ConsumerWidget {
  const HomeSearchBar({
    super.key,
    required this.hintText,
    required this.onSubmitted,
    this.leading,
    this.collapsed = false,
    this.onScrollToTop,
    this.currentQuery = '',
  });

  final String hintText;
  final ValueChanged<String> onSubmitted;
  final Widget? leading;
  final bool collapsed;
  final VoidCallback? onScrollToTop;
  final String currentQuery;

  Future<void> _openSearchPage(BuildContext context) async {
    final query = await context.push<String>(
      '/search',
      extra: {'initialQuery': currentQuery},
    );
    if (query != null && query.trim().isNotEmpty) {
      onSubmitted(query.trim());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
          children: [
            if (leading != null) leading!,
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: T.tapToSearch,
              onPressed: () => _openSearchPage(context),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _openSearchPage(context),
                child: Container(
                  height: 48,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    currentQuery.isNotEmpty ? currentQuery : T.tapToSearch,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: currentQuery.isNotEmpty
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            if (collapsed)
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded),
                  tooltip: T.backToTop,
                  onPressed: onScrollToTop,
                ),
              )
            else
              SizedBox(
                width: 40,
                height: 40,
                child: Tooltip(
                  message: T.switchColumns,
                  child: TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () {
                      final next = ref.read(gridColumnsProvider) >= 6
                          ? 2
                          : ref.read(gridColumnsProvider) + 1;
                      ref.read(gridColumnsProvider.notifier).state = next;
                    },
                    child: Text('${ref.watch(gridColumnsProvider)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
    );
  }
}
