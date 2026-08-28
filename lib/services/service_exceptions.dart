/// Base class for recoverable, user-facing service errors.
sealed class ServiceException implements Exception {
  const ServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A cloud provider returned an error or no API key is configured.
class RemoteApiException extends ServiceException {
  const RemoteApiException(super.message, {this.statusCode});
  final int? statusCode;
}

/// No API key configured for the active provider.
class MissingApiKeyException extends ServiceException {
  const MissingApiKeyException(super.message);
}
