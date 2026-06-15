/// Base class for recoverable, user-facing service errors.
sealed class ServiceException implements Exception {
  const ServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A required on-device model has not been downloaded yet.
class ModelNotDownloadedException extends ServiceException {
  const ModelNotDownloadedException(super.message);
}

/// A cloud provider returned an error or no API key is configured.
class RemoteApiException extends ServiceException {
  const RemoteApiException(super.message, {this.statusCode});
  final int? statusCode;
}

/// Audio decoding / conversion failed.
class AudioProcessingException extends ServiceException {
  const AudioProcessingException(super.message);
}

/// No API key configured for the active provider.
class MissingApiKeyException extends ServiceException {
  const MissingApiKeyException(super.message);
}
