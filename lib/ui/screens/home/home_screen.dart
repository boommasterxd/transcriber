import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_import.dart';
import 'widgets/phone_home_view.dart';

/// App home: search, active model, manual file import, history, and recording.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return PhoneHomeView(
      query: _query,
      onQueryChanged: (query) => setState(() => _query = query),
      onPickFile: () => startAudioImport(context),
    );
  }
}
