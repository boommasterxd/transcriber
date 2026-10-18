import 'selection_graph.dart';

const knownAssetOwners = <String, String>{
  'assets/images/providers/openai.png': 'lib/ui/widgets/provider_logo.dart',
  'assets/images/providers/openai_dark.png':
      'lib/ui/widgets/provider_logo.dart',
  'assets/images/providers/gemini.png': 'lib/ui/widgets/provider_logo.dart',
};

bool addAssetDependencies(
  ImportGraph graph,
  ImportGraph execution,
  List<String> changed,
  Set<String> checkoutPaths,
) {
  for (final asset in changed.where(knownAssetOwners.containsKey)) {
    final owner = knownAssetOwners[asset]!;
    if (!execution.containsKey(owner) || !checkoutPaths.contains(asset)) {
      return false;
    }
    graph[owner]!.add(asset);
  }
  return true;
}
