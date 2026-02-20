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
  final List<_VisualizerNode> _nodes = [];

  @override
  void initState() {
    super.initState();
    // 4-second loop gives us a solid rhythmic base to calculate mathematical "beats"
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _generateNodes();

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

  void _generateNodes() {
    // Fixed seed so the layout remains consistent across rebuilds
    final random = math.Random(42);

    // Generate 24 random shapes scattered around the screen
    for (int i = 0; i < 24; i++) {
      _nodes.add(
        _VisualizerNode(
          type: ShapeType.values[random.nextInt(ShapeType.values.length)],
          relX: random.nextDouble(), // 0.0 to 1.0 (relative screen width)
          relY: random.nextDouble(), // 0.0 to 1.0 (relative screen height)
          baseSize: 15.0 + random.nextDouble() * 45.0,
          beatBand: random.nextInt(3), // 0: Bass, 1: Mids, 2: Highs
          rotationSpeed: (random.nextDouble() - 0.5) * 4,
          floatSpeedX: (random.nextDouble() - 0.5) * 30,
          floatSpeedY: (random.nextDouble() - 0.5) * 30,
        ),
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
    final color = Colors.white.withOpacity(0.15);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t =
                _controller.value; // Ranges from 0.0 to 1.0 over 4 seconds

            // Simulate musical bands using math power functions to create sharp "snaps" or "kicks"
            // Over 4 seconds, 8 bass hits = 120 BPM
            final bassHit = math.pow(math.sin(t * math.pi * 8), 8).toDouble();
            final midHit = math.pow(math.sin(t * math.pi * 16), 4).toDouble();
            final highHit = math.pow(math.sin(t * math.pi * 32), 2).toDouble();

            return Stack(
              children: _nodes.map((node) {
                // Determine which rhythm band this specific shape reacts to
                double scaleMultiplier = 1.0;
                if (node.beatBand == 0) {
                  scaleMultiplier += bassHit * 0.7; // Bass expands large
                } else if (node.beatBand == 1) {
                  scaleMultiplier += midHit * 0.4; // Mids pulse medium
                } else {
                  scaleMultiplier += highHit * 0.2; // Highs flutter small
                }

                // Add organic floating based on time
                final floatX =
                    math.sin(t * math.pi * 2 + node.relY) * node.floatSpeedX;
                final floatY =
                    math.cos(t * math.pi * 2 + node.relX) * node.floatSpeedY;

                final xPos = (node.relX * screenWidth) + floatX;
                final yPos = (node.relY * screenHeight) + floatY;

                return Positioned(
                  left: xPos,
                  top: yPos,
                  child: Transform.translate(
                    offset: Offset(-node.baseSize / 2, -node.baseSize / 2),
                    child: Transform.scale(
                      scale: scaleMultiplier,
                      child: Transform.rotate(
                        angle: t * math.pi * 2 * node.rotationSpeed,
                        child: CustomPaint(
                          size: Size(node.baseSize, node.baseSize),
                          painter: _WireframePainter(
                            color: color,
                            shapeType: node.type,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

enum ShapeType { triangle, square, diamond, pentagon, hexagon, circle }

class _VisualizerNode {
  final ShapeType type;
  final double relX;
  final double relY;
  final double baseSize;
  final int beatBand;
  final double rotationSpeed;
  final double floatSpeedX;
  final double floatSpeedY;

  _VisualizerNode({
    required this.type,
    required this.relX,
    required this.relY,
    required this.baseSize,
    required this.beatBand,
    required this.rotationSpeed,
    required this.floatSpeedX,
    required this.floatSpeedY,
  });
}

class _WireframePainter extends CustomPainter {
  final Color color;
  final ShapeType shapeType;

  _WireframePainter({required this.color, required this.shapeType});

  void _drawPolygon(Canvas canvas, Size size, Paint paint, int sides) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final path = Path();

    for (int i = 0; i < sides; i++) {
      // Start pointing straight up (-pi / 2)
      final angle = (i * 2 * math.pi / sides) - (math.pi / 2);
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;

    switch (shapeType) {
      case ShapeType.triangle:
        _drawPolygon(canvas, size, paint, 3);
        break;
      case ShapeType.square:
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
        break;
      case ShapeType.diamond:
        // A diamond is just a square rotated 45 degrees, drawn via polygon math for centering
        _drawPolygon(canvas, size, paint, 4);
        break;
      case ShapeType.pentagon:
        _drawPolygon(canvas, size, paint, 5);
        break;
      case ShapeType.hexagon:
        _drawPolygon(canvas, size, paint, 6);
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
  bool shouldRepaint(covariant _WireframePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.shapeType != shapeType;
  }
}
