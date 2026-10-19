/// A model exposed by a provider's model catalog.
class RemoteModelInfo {
  const RemoteModelInfo({required this.id, this.label});

  final String id;
  final String? label;

  String get display => label?.isNotEmpty == true ? label! : id;
}
