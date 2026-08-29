import 'dart:io';

String? classifyLiveSocketClosure(int? closeCode, String? closeReason) {
  if (closeCode == null || closeCode == WebSocketStatus.normalClosure) {
    return null;
  }
  return classifyProviderFailure(
    code: closeCode.toString(),
    message: closeReason,
  );
}

String classifyProviderFailure({Object? code, Object? message}) {
  final detail = '${code ?? ''} ${message ?? ''}'.toLowerCase();
  if (_containsAny(detail, const [
    'api key',
    'invalid_api_key',
    'authentication',
    'unauthenticated',
    'unauthorized',
    '401',
  ])) {
    return 'authentication_failed';
  }
  if (_containsAny(detail, const [
    'quota',
    'rate_limit',
    'rate limit',
    'resource_exhausted',
    'billing',
    '429',
  ])) {
    return 'quota_exceeded';
  }
  if (_containsAny(detail, const [
    'model',
    'not_found',
    'not found',
    'unsupported',
    'unavailable',
  ])) {
    return 'model_unavailable';
  }
  if (_containsAny(detail, const [
    'permission',
    'access denied',
    'forbidden',
    '403',
  ])) {
    return 'provider_access_denied';
  }
  if (_containsAny(detail, const [
    'invalid_request',
    'invalid argument',
    'configuration',
    'language',
    '1007',
  ])) {
    return 'configuration_rejected';
  }
  return 'provider_rejected';
}

bool _containsAny(String value, List<String> needles) =>
    needles.any(value.contains);
