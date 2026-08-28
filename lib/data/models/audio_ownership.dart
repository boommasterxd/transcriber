/// Whether an audio path belongs to the user or to app-managed storage.
enum AudioOwnership {
  external('external'),
  temporary('temporary'),
  retained('retained');

  const AudioOwnership(this.id);

  final String id;

  static AudioOwnership fromId(String? id) => AudioOwnership.values.firstWhere(
    (ownership) => ownership.id == id,
    orElse: () => AudioOwnership.external,
  );
}
