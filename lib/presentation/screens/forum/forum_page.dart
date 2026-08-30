import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';

class ForumPage extends StatelessWidget {
  const ForumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(T.forum)),
      body: Center(
        child: EmptyState(icon: Icons.forum, title: T.noForumContent),
      ),
    );
  }
}
