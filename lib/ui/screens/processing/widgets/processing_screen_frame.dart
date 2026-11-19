import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_palette.dart';

class ProcessingScreenFrame extends StatelessWidget {
  const ProcessingScreenFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.bg,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}
