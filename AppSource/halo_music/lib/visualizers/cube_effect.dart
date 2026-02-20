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
  final List<_CubeNode> _cubes = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _generateCubes();

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

  void _generateCubes() {
    final random = math.Random(42);
    for (int i = 0; i < 15; i++) {
      _cubes.add(
        _CubeNode(
          relX: random.nextDouble(),
          relY: random.nextDouble(),
          baseSize: 20.0 + random.nextDouble() * 40.0,
          beatBand: random.nextInt(3),
          rotSpeedX: (random.nextDouble() - 0.5) * 2,
          rotSpeedY: (random.nextDouble() - 0.5) * 2,
          rotSpeedZ: (random.nextDouble() - 0.5) * 2,
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        final bassHit = math.pow(math.sin(t * math.pi * 8), 8).toDouble();
        final midHit = math.pow(math.sin(t * math.pi * 16), 4).toDouble();
        final highHit = math.pow(math.sin(t * math.pi * 32), 2).toDouble();

        return CustomPaint(
          size: Size.infinite,
          painter: _CubePainter(
            cubes: _cubes,
            t: t,
            bassHit: bassHit,
            midHit: midHit,
            highHit: highHit,
            color: widget.colorScheme.primary.withOpacity(0.3),
          ),
        );
      },
    );
  }
}

class _CubeNode {
  final double relX;
  final double relY;
  final double baseSize;
  final int beatBand;
  final double rotSpeedX;
  final double rotSpeedY;
  final double rotSpeedZ;

  _CubeNode({
    required this.relX,
    required this.relY,
    required this.baseSize,
    required this.beatBand,
    required this.rotSpeedX,
    required this.rotSpeedY,
    required this.rotSpeedZ,
  });
}

class _CubePainter extends CustomPainter {
  final List<_CubeNode> cubes;
  final double t;
  final double bassHit;
  final double midHit;
  final double highHit;
  final Color color;

  _CubePainter({
    required this.cubes,
    required this.t,
    required this.bassHit,
    required this.midHit,
    required this.highHit,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    for (var cube in cubes) {
      double scale = 1.0;
      if (cube.beatBand == 0)
        scale += bassHit * 0.6;
      else if (cube.beatBand == 1)
        scale += midHit * 0.3;
      else
        scale += highHit * 0.15;

      final floatY = math.sin(t * math.pi * 2 + cube.relX) * 20;
      final cx = cube.relX * size.width;
      final cy = cube.relY * size.height + floatY;
      final currentSize = cube.baseSize * scale;

      _draw3DCube(
        canvas,
        paint,
        cx,
        cy,
        currentSize,
        t * math.pi * 2 * cube.rotSpeedX,
        t * math.pi * 2 * cube.rotSpeedY,
        t * math.pi * 2 * cube.rotSpeedZ,
      );
    }
  }

  void _draw3DCube(
    Canvas canvas,
    Paint paint,
    double cx,
    double cy,
    double size,
    double rx,
    double ry,
    double rz,
  ) {
    // Standard cube vertices (-1 to 1)
    List<List<double>> vertices = [
      [-1, -1, -1],
      [1, -1, -1],
      [1, 1, -1],
      [-1, 1, -1],
      [-1, -1, 1],
      [1, -1, 1],
      [1, 1, 1],
      [-1, 1, 1],
    ];

    List<Offset> projected = [];

    for (var v in vertices) {
      double x = v[0], y = v[1], z = v[2];

      // Rotate X
      double tempY = y * math.cos(rx) - z * math.sin(rx);
      double tempZ = y * math.sin(rx) + z * math.cos(rx);
      y = tempY;
      z = tempZ;

      // Rotate Y
      double tempX = x * math.cos(ry) + z * math.sin(ry);
      z = -x * math.sin(ry) + z * math.cos(ry);
      x = tempX;

      // Rotate Z
      tempX = x * math.cos(rz) - y * math.sin(rz);
      tempY = x * math.sin(rz) + y * math.cos(rz);
      x = tempX;
      y = tempY;

      // Simple orthographic projection with scale
      projected.add(Offset(cx + x * size, cy + y * size));
    }

    // Draw edges
    final edges = [
      [0, 1], [1, 2], [2, 3], [3, 0], // Back face
      [4, 5], [5, 6], [6, 7], [7, 4], // Front face
      [0, 4], [1, 5], [2, 6], [3, 7], // Connecting lines
    ];

    for (var edge in edges) {
      canvas.drawLine(projected[edge[0]], projected[edge[1]], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
