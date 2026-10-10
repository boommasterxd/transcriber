import 'package:flutter/material.dart';
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
import '../../../widgets/surfaces.dart';
import 'model_sheet_frame.dart';
import 'remote_model_options.dart';
import 'remote_stage.dart';

/// Returns a live, connected model choice immediately when it is selected.
Future<RemoteModelSelection?> showRemoteModelSheet(
  BuildContext context, {
  required RemoteStage stage,
  required RemoteModelSelection selection,
  required List<RemoteProviderId> allowedProviders,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<RemoteModelSelection>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    constraints: MediaQuery.sizeOf(context).width >= 720
        ? const BoxConstraints(maxWidth: 600)
        : null,
    builder: (_) => RemoteModelSheet(
      stage: stage,
      selection: selection,
      allowedProviders: allowedProviders,
    ),
  );
}

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
  late String _modelId;
  bool _completed = false;

  bool get _transcription => widget.stage.forTranscription;
  RemoteModelsQuery get _query =>
      (provider: _provider, forTranscription: _transcription);

  @override
  void initState() {
    super.initState();
    _provider = widget.selection.provider;
    _modelId = widget.selection.modelId;
  }

  void _selectProvider(RemoteProviderId provider) {
    if (_completed || provider == _provider) return;
    setState(() {
      _provider = provider;
      _modelId = widget.selection.provider == provider
          ? widget.selection.modelId
          : '';
    });
  }

  void _selectModel(String? modelId) {
    if (_completed || modelId == null) return;
    final connected =
        ref.read(connectionsControllerProvider)[_provider] ?? false;
    final catalog = ref.read(remoteModelsProvider(_query));
    if (!connected ||
        !widget.allowedProviders.contains(_provider) ||
        catalog.isLoading ||
        catalog.hasError ||
        !(catalog.asData?.value.any((model) => model.id == modelId) ?? false)) {
      return;
    }
    _completed = true;
    Navigator.of(context).pop((provider: _provider, modelId: modelId));
  }

  Future<void> _refreshModels() async {
    final query = _query;
    if (_completed ||
        !widget.allowedProviders.contains(query.provider) ||
        !(ref.read(connectionsControllerProvider)[query.provider] ?? false)) {
      return;
    }
    try {
      ref.invalidate(remoteModelsProvider(query));
      await ref.read(remoteModelsProvider(query).future);
    } catch (_) {
      // Catalog errors are rendered through the existing sanitized error state.
    }
  }

  Widget _catalogBody(
    AppStrings strings,
    List<RemoteProviderId> providers,
    AsyncValue<List<RemoteModelInfo>>? catalog,
  ) => RadioGroup<String>(
    groupValue: _modelId,
    onChanged: _selectModel,
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.f5): _refreshModels},
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: strings.refreshModels): _refreshModels,
        },
        child: RefreshIndicator(
          onRefresh: _refreshModels,
          semanticsLabel: strings.refreshModels,
          child: FadeEdges(
            shrinkWrap: true,
            color: context.palette.surface,
            builder: (_, controller) =>
                _catalogScrollView(strings, providers, catalog, controller),
          ),
        ),
      ),
    ),
  );

  Widget _catalogScrollView(
    AppStrings strings,
    List<RemoteProviderId> providers,
    AsyncValue<List<RemoteModelInfo>>? catalog,
    ScrollController controller,
  ) => CustomScrollView(
    controller: controller,
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
          onRetry: () => ref.invalidate(remoteModelsProvider(_query)),
          strings: strings,
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final connections = ref.watch(connectionsControllerProvider);
    final providers = widget.allowedProviders
        .where((provider) => connections[provider] ?? false)
        .toList();
    if (providers.isNotEmpty && !providers.contains(_provider)) {
      _provider = providers.first;
      _modelId = '';
    }
    final catalog = providers.isEmpty
        ? null
        : ref.watch(remoteModelsProvider(_query));
    return ModelSheetFrame(child: _catalogBody(strings, providers, catalog));
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
                    ? context.palette.accent
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
