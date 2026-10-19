/// Stable accent identifiers. Presentation code supplies their colors.
enum AppAccent {
  violet('violet'),
  blue('blue'),
  emerald('emerald'),
  amber('amber'),
  magenta('magenta');

  const AppAccent(this.id);

  final String id;

  static AppAccent fromId(String? id) => AppAccent.values.firstWhere(
    (accent) => accent.id == id,
    orElse: () => AppAccent.blue,
  );
}
