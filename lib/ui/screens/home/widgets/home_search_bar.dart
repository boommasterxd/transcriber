import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

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

  @override
  void didUpdateWidget(HomeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.query) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tablet = widget.style == HomeSearchStyle.tablet;
    return Container(
      height: tablet ? 44 : 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: tablet ? palette.bg : palette.surface,
        borderRadius: BorderRadius.circular(9999),
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
              onChanged: widget.onChanged,
              style: TextStyle(fontSize: tablet ? 14 : 15, color: palette.ink),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: TextStyle(
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
