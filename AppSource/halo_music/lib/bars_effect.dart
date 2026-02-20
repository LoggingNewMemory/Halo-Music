import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

class BarsVisualizer extends StatefulWidget {
  final Color color;
  final Stream<PlaybackState> playbackStream;

  const BarsVisualizer({
    super.key,
    required this.color,
    required this.playbackStream,
  });

  @override
  State<BarsVisualizer> createState() => _BarsVisualizerState();
}

class _BarsVisualizerState extends State<BarsVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Faster loop for bars
    );

    widget.playbackStream.listen((state) {
      if (mounted) {
        if (state.playing) {
          _controller.repeat();
        } else {
          _controller.stop();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _BarsPainter(
            t: _controller.value,
            // Removed .withOpacity(0.5) so it exactly matches the play button!
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _BarsPainter extends CustomPainter {
  final double t;
  final Color color;

  _BarsPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const barCount = 30;
    final spacing = size.width / barCount;
    final barWidth = spacing * 0.6;
    final maxHeight = size.height * 0.4;

    final beat = math.sin(t * math.pi * 2);

    for (int i = 0; i < barCount; i++) {
      final frequencyCurve = math.sin(i * 0.5 + t * math.pi * 4) * 0.5 + 0.5;
      final fastNoise = math.cos(i * 1.2 - t * math.pi * 8) * 0.5 + 0.5;

      final normalizedHeight =
          (frequencyCurve * 0.6 + fastNoise * 0.4) * (0.5 + (beat.abs() * 0.5));
      final barHeight = 10.0 + (normalizedHeight * maxHeight);

      final x = (i * spacing) + (spacing - barWidth) / 2;
      final y = size.height - barHeight;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(4.0),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
