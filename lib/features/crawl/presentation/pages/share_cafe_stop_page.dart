import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ShareCafeStopPage extends StatelessWidget {
  const ShareCafeStopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Share Cafe Stop'),
      ),
      body: const Center(
        child: Text('Coming soon'),
      ),
    );
  }
}
