import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../state/processing_controller.dart';

/// Provides the shared lifecycle for views that own a processing run.
mixin ProcessingControllerLifecycle<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final ProcessingController processingController;

  /// Starts the processing run after the first frame has been rendered.
  void startProcessing();

  @override
  void initState() {
    super.initState();
    processingController = ref.read(processingControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) startProcessing();
    });
  }

  @override
  void dispose() {
    unawaited(processingController.discardCurrent());
    super.dispose();
  }
}
