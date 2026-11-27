import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';

enum HomeSearchStyle { phone, tablet }

/// Rounded search field that filters the transcript history.
class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.query = '',
    this.style = HomeSearchStyle.phone,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final HomeSearchStyle style;
  final String query;

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  late final _controller = TextEditingController(text: widget.query);
  Timer? _pendingSearch;
  String? _forwardedQuery;

  @override
  void didUpdateWidget(HomeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query == widget.query) return;
    if (widget.query == _forwardedQuery) {
      _forwardedQuery = null;
      return;
    }
    if (_controller.text != widget.query) {
      _pendingSearch?.cancel();
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _pendingSearch?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String query) {
    _pendingSearch?.cancel();
    _pendingSearch = Timer(
      const Duration(milliseconds: 180),
      () => _submitSearch(query),
    );
  }

  void _submitSearch(String query) {
    _pendingSearch?.cancel();
    _forwardedQuery = query;
    widget.onChanged(query);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tablet = widget.style == HomeSearchStyle.tablet;
    return Container(
      constraints: BoxConstraints(minHeight: tablet ? 44 : 48),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: tablet ? palette.bg : palette.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        boxShadow: tablet
            ? null
            : [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: tablet ? 17 : 18,
            color: palette.faint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _scheduleSearch,
              onSubmitted: _submitSearch,
              style: TextStyle(fontSize: tablet ? 14 : 15, color: palette.ink),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                labelText: widget.hint,
                labelStyle: TextStyle(
                  fontSize: tablet ? 14 : 15,
                  color: palette.faint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
