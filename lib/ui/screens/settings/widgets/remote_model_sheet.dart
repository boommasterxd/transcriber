import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../services/remote/remote_api_client.dart';
import '../../../../state/connections_controller.dart';
import '../../../../state/remote_models_provider.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/app_bottom_sheet.dart';
import 'remote_model_options.dart';
import 'remote_stage.dart';

typedef RemoteModelChoice = ({
  RemoteProviderId provider,
  String modelId,
  int credentialRevision,
});

/// Returns a live, connected model choice when the user activates it.
Future<RemoteModelChoice?> showRemoteModelSheet(
  BuildContext context, {
  required RemoteStage stage,
  required RemoteModelSelection selection,
  required List<RemoteProviderId> allowedProviders,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final providers = _connectedProviders(
    allowedProviders,
    container.read(connectionsControllerProvider),
  );
  final provider = _activeProvider(selection.provider, providers);
  if (provider != null) refreshRemoteModelCatalog(container, provider);
  return showAppBottomSheet<RemoteModelChoice>(
    context,
    useSafeArea: true,
    builder: (_) => RemoteModelSheet(
      stage: stage,
      selection: selection,
      allowedProviders: allowedProviders,
    ),
  );
}

List<RemoteProviderId> _connectedProviders(
  List<RemoteProviderId> allowed,
  Map<RemoteProviderId, bool> connections,
) => allowed.where((provider) => connections[provider] ?? false).toList();

RemoteProviderId? _activeProvider(
  RemoteProviderId selection,
  List<RemoteProviderId> connected,
) => connected.contains(selection) ? selection : connected.firstOrNull;

class RemoteModelSheet extends ConsumerStatefulWidget {
  const RemoteModelSheet({
    super.key,
    required this.stage,
    required this.selection,
    required this.allowedProviders,
  });

  final RemoteStage stage;
  final RemoteModelSelection selection;
  final List<RemoteProviderId> allowedProviders;

  @override
  ConsumerState<RemoteModelSheet> createState() => _RemoteModelSheetState();
}

class _RemoteModelSheetState extends ConsumerState<RemoteModelSheet> {
  late RemoteProviderId _provider;
  bool _completed = false;

  ProviderContainer get _container =>
      ProviderScope.containerOf(context, listen: false);
  bool get _transcription => widget.stage.forTranscription;
  RemoteModelsQuery get _query =>
      (provider: _provider, forTranscription: _transcription);

  @override
  void initState() {
    super.initState();
    _provider = widget.selection.provider;
  }

  void _selectProvider(RemoteProviderId provider) {
    if (_completed || provider == _provider || !_canLoad(provider)) return;
    refreshRemoteModelCatalog(_container, provider);
    setState(() => _provider = provider);
  }

  void _selectModel(
    RemoteModelsQuery query,
    AsyncValue<List<RemoteModelInfo>> displayed,
    String modelId,
  ) {
    if (_completed || query != _query || !_canLoad(query.provider)) return;
    if (refreshRemoteModelCatalog(_container, query.provider)) return;
    final catalog = ref.read(remoteModelsProvider(query));
    if (catalog.isLoading ||
        catalog.hasError ||
        !identical(catalog.asData?.value, displayed.asData?.value)) {
      return;
    }
    final revision = ref
        .read(connectionsControllerProvider.notifier)
        .catalogRevision(query.provider);
    _completed = true;
    Navigator.of(context).pop((
      provider: query.provider,
      modelId: modelId,
      credentialRevision: revision,
    ));
  }

  bool _canLoad(RemoteProviderId provider) =>
      widget.allowedProviders.contains(provider) &&
      (ref.read(connectionsControllerProvider)[provider] ?? false);

  Future<void> _refreshModels() async {
    final query = _query;
    if (_completed ||
        !_canLoad(query.provider) ||
        !refreshRemoteModelCatalog(_container, query.provider, force: true)) {
      return;
    }
    try {
      await ref.read(remoteModelsProvider(query).future);
    } catch (_) {
      // Catalog errors are rendered through the existing sanitized error state.
    }
  }

  Widget _catalogBody(
    AppStrings strings,
    List<RemoteProviderId> providers,
    AsyncValue<List<RemoteModelInfo>>? catalog,
    RemoteModelsQuery query,
  ) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.f5): _refreshModels},
    child: Semantics(
      customSemanticsActions: {
        if (catalog != null)
          CustomSemanticsAction(label: strings.refreshModels): _refreshModels,
      },
      child: RefreshIndicator(
        onRefresh: _refreshModels,
        semanticsLabel: strings.refreshModels,
        child: _catalogScrollView(strings, providers, catalog, query),
      ),
    ),
  );

  Widget _catalogScrollView(
    AppStrings strings,
    List<RemoteProviderId> providers,
    AsyncValue<List<RemoteModelInfo>>? catalog,
    RemoteModelsQuery query,
  ) => CustomScrollView(
    shrinkWrap: true,
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            header: true,
            child: Text(
              _transcription
                  ? strings.transcriptionModelTitle
                  : strings.summaryModelTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.palette.ink,
              ),
            ),
          ),
        ),
      ),
      if (providers.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          sliver: SliverToBoxAdapter(
            child: _ProviderChoices(
              providers: providers,
              selected: _provider,
              onSelect: _selectProvider,
            ),
          ),
        ),
      if (catalog == null)
        SliverToBoxAdapter(child: Text(strings.connectFirst))
      else
        RemoteModelOptions(
          catalog: catalog,
          selectedModelId: _provider == widget.selection.provider
              ? widget.selection.modelId
              : null,
          onSelect: (modelId) => _selectModel(query, catalog, modelId),
          onRefresh: _refreshModels,
          strings: strings,
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final connections = ref.watch(connectionsControllerProvider);
    ref.listen(connectionsControllerProvider, (_, next) {
      final providers = _connectedProviders(widget.allowedProviders, next);
      final provider = _activeProvider(_provider, providers);
      if (provider != null && provider != _provider) {
        refreshRemoteModelCatalog(_container, provider);
      }
    });
    final providers = _connectedProviders(widget.allowedProviders, connections);
    final provider = _activeProvider(_provider, providers);
    if (provider != null) _provider = provider;
    final query = _query;
    final catalog = provider == null
        ? null
        : ref.watch(remoteModelsProvider(query));
    return AppBottomSheetFrame(
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: _catalogBody(strings, providers, catalog, query),
    );
  }
}

class _ProviderChoices extends StatelessWidget {
  const _ProviderChoices({
    required this.providers,
    required this.selected,
    required this.onSelect,
  });

  final List<RemoteProviderId> providers;
  final RemoteProviderId selected;
  final ValueChanged<RemoteProviderId> onSelect;

  @override
  Widget build(BuildContext context) {
    if (providers.length == 1) {
      return Text(
        RemoteCatalog.provider(providers.single).name,
        style: TextStyle(color: context.palette.body),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final provider in providers)
          Semantics(
            selected: provider == selected,
            child: TextButton(
              key: ValueKey('provider-${provider.id}'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: provider == selected
                    ? context.palette.accentDeep
                    : context.palette.body,
                backgroundColor: provider == selected
                    ? context.palette.accentSoft
                    : context.palette.chip,
              ),
              onPressed: () => onSelect(provider),
              child: Text(RemoteCatalog.provider(provider).name),
            ),
          ),
      ],
    );
  }
}
