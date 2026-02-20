import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

class CubeEqualizer extends StatefulWidget {
  final ColorScheme colorScheme;
  final Stream<PlaybackState> playbackStream;

  const CubeEqualizer({
    super.key,
    required this.colorScheme,
    required this.playbackStream,
  });

  @override
  State<CubeEqualizer> createState() => _CubeEqualizerState();
}

class _CubeEqualizerState extends State<CubeEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 12 second continuous loop for organic floating
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
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
    final color = Colors.white.withOpacity(0.25);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Use sine and cosine waves to create organic floating movements
        return Stack(
          children: [
            // Top Left: Triangle
            Positioned(
              top: 150 + (math.sin(t * 2 * math.pi) * 20),
              left: 60 + (math.cos(t * 2 * math.pi) * 15),
              child: Transform.rotate(
                angle: t * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(60, 60),
                  painter: _WireframePainter(
                    color: color,
                    shapeType: ShapeType.triangle,
                  ),
                ),
              ),
            ),
            // Top Right: Tilted Square
            Positioned(
              top: 120 + (math.cos(t * 2 * math.pi + 1) * 25),
              right: 80 + (math.sin(t * 2 * math.pi + 1) * 20),
              child: Transform.rotate(
                angle: -(t * 2 * math.pi) + 0.5,
                child: CustomPaint(
                  size: const Size(55, 55),
                  painter: _WireframePainter(
                    color: color,
                    shapeType: ShapeType.square,
                  ),
                ),
              ),
            ),
            // Middle Left: Circle
            Positioned(
              top: 300 + (math.sin(t * 2 * math.pi + 2) * 15),
              left: 40 + (math.cos(t * 2 * math.pi + 2) * 10),
              child: Transform.scale(
                scale: 1.0 + (math.sin(t * 4 * math.pi) * 0.1), // Gentle pulse
                child: CustomPaint(
                  size: const Size(65, 65),
                  painter: _WireframePainter(
                    color: color,
                    shapeType: ShapeType.circle,
                  ),
                ),
              ),
            ),
            // Mid Bottom: Diamond
            Positioned(
              top: 450 + (math.cos(t * 2 * math.pi + 3) * 30),
              left: 100 + (math.sin(t * 2 * math.pi + 3) * 20),
              child: Transform.rotate(
                angle:
                    (t * 2 * math.pi) + (math.pi / 4), // Kept in diamond shape
                child: CustomPaint(
                  size: const Size(50, 50),
                  painter: _WireframePainter(
                    color: color,
                    shapeType:
                        ShapeType.square, // Square rotated 45deg is a diamond
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum ShapeType { triangle, square, circle }

class _WireframePainter extends CustomPainter {
  final Color color;
  final ShapeType shapeType;

  _WireframePainter({required this.color, required this.shapeType});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    switch (shapeType) {
      case ShapeType.triangle:
        final path = Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.square:
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
        break;
      case ShapeType.circle:
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          size.width / 2,
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
