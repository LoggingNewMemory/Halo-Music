import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

class WaveVisualizer extends StatefulWidget {
  final ColorScheme colorScheme;
  final Stream<PlaybackState> playbackStream;

  const WaveVisualizer({
    super.key,
    required this.colorScheme,
    required this.playbackStream,
  });

  @override
  State<WaveVisualizer> createState() => _WaveVisualizerState();
}

class _WaveVisualizerState extends State<WaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
          painter: _WavePainter(
            t: _controller.value,
            color: widget.colorScheme.primary.withOpacity(0.4),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  final Color color;

  _WavePainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2 - 50,
    ); // Offset slightly to match cover art
    final baseRadius = size.width * 0.45;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0); // Slight glow

    final path = Path();
    const points = 120;

    // Simulate audio reactivity with complex overlapping sine waves
    final beat = math.pow(math.sin(t * math.pi * 4), 2).toDouble();

    for (int i = 0; i <= points; i++) {
      final angle = (i / points) * math.pi * 2;

      // Generate pseudo-random waveform peaks
      final noise =
          math.sin(angle * 6 + t * math.pi * 2) * 15 * beat +
          math.cos(angle * 12 - t * math.pi * 4) * 8 * beat;

      final radius = baseRadius + noise;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
