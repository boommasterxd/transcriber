import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../services/remote/remote_api_client.dart';
import '../../../../state/remote_models_provider.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/model_tile.dart';
import '../../../widgets/surfaces.dart';

/// Compact live model picker with the active model always visible.
class RemoteModelList extends ConsumerStatefulWidget {
  const RemoteModelList({
    super.key,
    required this.provider,
    required this.forTranscription,
    required this.selectedId,
    required this.onSelect,
  });

  final RemoteProviderId provider;
  final bool forTranscription;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  ConsumerState<RemoteModelList> createState() => _RemoteModelListState();
}

class _RemoteModelListState extends ConsumerState<RemoteModelList> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant RemoteModelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider ||
        oldWidget.forTranscription != widget.forTranscription) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strings = ref.watch(stringsProvider);
    final async = ref.watch(
      remoteModelsProvider((
        provider: widget.provider,
        forTranscription: widget.forTranscription,
      )),
    );

    Widget messageCard(Widget child) => SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Center(child: child),
    );

    return async.when(
      loading: () => messageCard(
        SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(palette.accent),
          ),
        ),
      ),
      error: (error, _) => messageCard(
        Text(
          error.toString(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: palette.coralInk),
        ),
      ),
      data: (models) => models.isEmpty
          ? messageCard(
              Text(
                strings.connectFirst,
                style: TextStyle(fontSize: 13.5, color: palette.muted),
              ),
            )
          : _ModelPickerCard(
              models: models,
              selectedId: widget.selectedId,
              forTranscription: widget.forTranscription,
              expanded: _expanded,
              expandLabel: _expanded ? strings.hideModels : strings.showModels,
              onToggle: () => setState(() => _expanded = !_expanded),
              onSelect: (modelId) {
                widget.onSelect(modelId);
                setState(() => _expanded = false);
              },
            ),
    );
  }
}

class _ModelPickerCard extends StatelessWidget {
  const _ModelPickerCard({
    required this.models,
    required this.selectedId,
    required this.forTranscription,
    required this.expanded,
    required this.expandLabel,
    required this.onToggle,
    required this.onSelect,
  });

  final List<RemoteModelInfo> models;
  final String selectedId;
  final bool forTranscription;
  final bool expanded;
  final String expandLabel;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = _activeModel();
    final alternatives = models
        .where((model) => model.id != active.id)
        .toList();
    final canExpand = alternatives.isNotEmpty;
    return SurfaceCard(
      clip: true,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _ActiveModelTile(
              model: active,
              forTranscription: forTranscription,
              expanded: expanded,
              expandLabel: expandLabel,
              onTap: canExpand ? onToggle : null,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: expanded && canExpand
                  ? Column(
                      children: [
                        for (final (index, model) in alternatives.indexed)
                          ModelTile(
                            leading: _ModelIcon(
                              forTranscription: forTranscription,
                            ),
                            title: model.display,
                            subtitle: model.display == model.id ? '' : model.id,
                            isLast: index == alternatives.length - 1,
                            trailing: const SelectionIndicator(selected: false),
                            onTap: () => onSelect(model.id),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  RemoteModelInfo _activeModel() {
    for (final model in models) {
      if (model.id == selectedId) return model;
    }
    return RemoteModelInfo(
      id: selectedId.isEmpty ? models.first.id : selectedId,
    );
  }
}

class _ActiveModelTile extends StatelessWidget {
  const _ActiveModelTile({
    required this.model,
    required this.forTranscription,
    required this.expanded,
    required this.expandLabel,
    required this.onTap,
  });

  final RemoteModelInfo model;
  final bool forTranscription;
  final bool expanded;
  final String expandLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: onTap != null,
      expanded: expanded,
      label: expandLabel,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.accentSoft2,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: _ModelIcon(forTranscription: forTranscription),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.display,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    if (model.display != model.id)
                      Text(
                        model.id,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: palette.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const SelectionIndicator(selected: true),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: palette.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelIcon extends StatelessWidget {
  const _ModelIcon({required this.forTranscription});

  final bool forTranscription;

  @override
  Widget build(BuildContext context) => Icon(
    forTranscription ? Icons.graphic_eq_rounded : Icons.auto_awesome_outlined,
    size: 18,
    color: context.palette.accent,
  );
}
