import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/dictation/live_failure_classifier.dart';

void main() {
  test('classifies provider failures without exposing provider details', () {
    expect(
      classifyProviderFailure(message: 'API key not valid'),
      'authentication_failed',
    );
    expect(classifyProviderFailure(code: 429), 'quota_exceeded');
    expect(
      classifyProviderFailure(message: 'Model is unsupported'),
      'model_unavailable',
    );
    expect(classifyProviderFailure(code: 403), 'provider_access_denied');
    expect(
      classifyProviderFailure(message: 'Invalid argument: language'),
      'configuration_rejected',
    );
    expect(
      classifyProviderFailure(message: 'Unclassified provider response'),
      'provider_rejected',
    );
  });

  test('treats only abnormal socket closures as provider failures', () {
    expect(classifyLiveSocketClosure(null, null), isNull);
    expect(
      classifyLiveSocketClosure(WebSocketStatus.normalClosure, null),
      isNull,
    );
    expect(
      classifyLiveSocketClosure(1007, 'Invalid configuration'),
      'configuration_rejected',
    );
  });
}
