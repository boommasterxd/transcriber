import '../service_exceptions.dart';

const _credentialQueryNames = {
  'key',
  'api_key',
  'api-key',
  'apikey',
  'x-goog-api-key',
  'access_token',
  'oauth_token',
  'authorization',
  'x-goog-credential',
  'x-goog-signature',
};

/// The resumable session URL may carry an opaque upload ID.
Uri validateGeminiUploadUri(String value, String host, String apiKey) {
  const invalid = RemoteApiException('Gemini returned an invalid upload URL.');
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != host ||
      uri.port != 443 ||
      uri.authority.contains('@') ||
      uri.hasFragment) {
    throw invalid;
  }
  try {
    if (_hasCredential(uri, apiKey)) throw invalid;
  } on FormatException {
    throw invalid;
  }
  return uri;
}

bool _hasCredential(Uri uri, String apiKey) {
  final params = uri.queryParametersAll;
  if (params.keys.any(
    (name) => _credentialQueryNames.contains(name.toLowerCase()),
  )) {
    return true;
  }
  if (apiKey.isEmpty) return false;
  return [
    ...uri.pathSegments,
    ...params.keys,
    ...params.values.expand((values) => values),
  ].any((part) => part.contains(apiKey));
}
