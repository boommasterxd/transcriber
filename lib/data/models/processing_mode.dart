/// Whether processing runs fully on-device or via a cloud API. These are
/// mutually exclusive — never both — exactly as required by the design.
enum ProcessingMode {
  onDevice('local'),
  cloud('remote');

  const ProcessingMode(this.id);
  final String id;

  bool get isLocal => this == ProcessingMode.onDevice;
  bool get isCloud => this == ProcessingMode.cloud;

  static ProcessingMode fromId(String? id) =>
      id == 'remote' ? ProcessingMode.cloud : ProcessingMode.onDevice;
}
