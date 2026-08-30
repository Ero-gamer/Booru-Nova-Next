import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/app_placeholders.dart';
import 'package:flutter/material.dart';

class ArtistsPage extends StatelessWidget {
  const ArtistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(T.artists)),
      body: Center(
        child: EmptyState(icon: Icons.palette, title: T.artistsNotImplemented),
      ),
    );
  }
}
