import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../data/models/remote_provider.dart';

/// Compact local vector mark for a supported cloud provider.
class ProviderLogo extends StatelessWidget {
  const ProviderLogo({super.key, required this.provider, this.size = 38});

  final RemoteProviderId provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.19),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.29),
          border: Border.all(color: palette.line2),
        ),
        child: CustomPaint(
          painter: provider == RemoteProviderId.openai
              ? const _OpenAiLogoPainter()
              : const _GeminiLogoPainter(),
        ),
      ),
    );
  }
}

class _OpenAiLogoPainter extends CustomPainter {
  const _OpenAiLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.shortestSide * 0.105;
    final paint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (var index = 0; index < 6; index++) {
      canvas.save();
      canvas.rotate(index * math.pi / 3);
      final path = Path()
        ..moveTo(0, -size.height * 0.39)
        ..cubicTo(
          size.width * 0.22,
          -size.height * 0.39,
          size.width * 0.34,
          -size.height * 0.19,
          size.width * 0.25,
          0,
        )
        ..lineTo(size.width * 0.09, size.height * 0.27);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GeminiLogoPainter extends CustomPainter {
  const _GeminiLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..cubicTo(
        size.width * 0.54,
        size.height * 0.31,
        size.width * 0.69,
        size.height * 0.46,
        size.width,
        size.height * 0.5,
      )
      ..cubicTo(
        size.width * 0.69,
        size.height * 0.54,
        size.width * 0.54,
        size.height * 0.69,
        size.width * 0.5,
        size.height,
      )
      ..cubicTo(
        size.width * 0.46,
        size.height * 0.69,
        size.width * 0.31,
        size.height * 0.54,
        0,
        size.height * 0.5,
      )
      ..cubicTo(
        size.width * 0.31,
        size.height * 0.46,
        size.width * 0.46,
        size.height * 0.31,
        size.width * 0.5,
        0,
      )
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A73E8), Color(0xFF8E66D5), Color(0xFFD965B5)],
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
