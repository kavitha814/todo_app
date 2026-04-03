import 'package:flutter/material.dart';
import 'dart:math' as math;

class GrowingTree extends StatelessWidget {
  final double progress; // 0.0 to 1.0

  const GrowingTree({Key? key, required this.progress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return CustomPaint(
          painter: RealisticTreePainter(progress: progress),
          size: Size(size, size),
        );
      },
    );
  }
}

class RealisticTreePainter extends CustomPainter {
  final double progress;

  // Use a fixed random seed so the tree shape is consistent across frames
  final math.Random random = math.Random(42);

  RealisticTreePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // A bit of ground
    final groundPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.fill;
    
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width / 2, size.height), width: size.width * 0.8, height: 20),
      groundPaint,
    );

    if (progress <= 0) return; // Nothing to draw

    // Translate to the base of the tree
    canvas.save();
    canvas.translate(size.width / 2, size.height - 10);

    // Initial parameters for the trunk
    const int maxDepth = 7;
    // Map overall progress to depth progress. At progress=1.0, depth=maxDepth
    final double overallDepth = progress * maxDepth;

    // We scale the whole tree down a bit so it fits in the box
    final double initialLength = size.height * 0.25;

    _drawBranch(
      canvas,
      depth: 0,
      overallDepth: overallDepth,
      maxLength: initialLength,
      baseThickness: 18.0,
      angle: 0.0,
    );

    canvas.restore();
  }

  void _drawBranch(
    Canvas canvas, {
    required int depth,
    required double overallDepth,
    required double maxLength,
    required double baseThickness,
    required double angle,
  }) {
    if (depth > overallDepth) return; // Branch hasn't started growing yet

    canvas.save();

    // Rotate and animate the rotation slightly as it grows
    // When a branch first appears, it might "sprout" outward
    final double branchProgress = (overallDepth - depth).clamp(0.0, 1.0);
    // Smooth ease-out for branch growth
    final double easedProgress = 1.0 - math.pow(1.0 - branchProgress, 3);

    // Apply rotation. If it's the trunk (depth=0), no rotation.
    // Otherwise, animate the angle from 0 to the target angle.
    final double currentAngle = depth == 0 ? 0.0 : angle * easedProgress;
    canvas.rotate(currentAngle);

    final double currentLength = maxLength * easedProgress;

    // Trunk/branch paint
    final Paint woodPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..strokeWidth = baseThickness * easedProgress
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw the branch line
    canvas.drawLine(Offset.zero, Offset(0, -currentLength), woodPaint);

    // Move to the end of this branch
    canvas.translate(0, -currentLength);

    // Method to draw a clump of leaves
    void drawLeafClump(double scale) {
      final leafPaint = Paint()
        ..color = Color.lerp(Colors.lightGreen, Colors.green[800]!, random.nextDouble())!
        ..style = PaintingStyle.fill;
      
      final double leafScale = scale * (8.0 + random.nextDouble() * 6.0);
      
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -5), width: leafScale, height: leafScale * 1.5),
          leafPaint,
      );
      canvas.save();
      canvas.rotate(math.pi / 4);
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -5), width: leafScale, height: leafScale * 1.5),
          leafPaint,
      );
      canvas.restore();
      canvas.save();
      canvas.rotate(-math.pi / 4);
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -5), width: leafScale, height: leafScale * 1.5),
          leafPaint,
      );
      canvas.restore();
    }

    // Intermediary leaves: sprouted along the branch once it has grown a bit
    if (depth >= 2 && depth < 6) {
      // Offset by 0.5 so leaves start growing midway through the branch's life cycle
      final double intermediateLeafProgress = (overallDepth - depth - 0.5).clamp(0.0, 1.0);
      if (intermediateLeafProgress > 0 && random.nextDouble() > 0.3) {
        canvas.save();
        // Sprout halfway down the current branch
        canvas.translate(0, currentLength * 0.5);
        canvas.rotate(random.nextDouble() > 0.5 ? math.pi / 2.5 : -math.pi / 2.5);
        drawLeafClump(intermediateLeafProgress * 0.7); // slightly smaller leaves
        canvas.restore();
      }
    }

    // If this branch is fully grown enough to spawn children, do so
    if (depth + 1 <= overallDepth) {
      if (depth < 6) { // Recursion limit for branches
        // Spawn 2 or 3 branches
        int numBranches = (depth == 0) ? 3 : (random.nextDouble() > 0.3 ? 2 : 3);
        
        for (int i = 0; i < numBranches; i++) {
          // Angles spread left and right
          double newAngle;
          if (numBranches == 2) {
             newAngle = (i == 0 ? -1 : 1) * (math.pi / 6 + random.nextDouble() * 0.2);
          } else {
             newAngle = (i - 1) * (math.pi / 5 + random.nextDouble() * 0.2); // -1, 0, 1
          }

          // Next branch is shorter and thinner
          _drawBranch(
            canvas,
            depth: depth + 1,
            overallDepth: overallDepth,
            maxLength: maxLength * (0.65 + random.nextDouble() * 0.15),
            baseThickness: baseThickness * 0.65,
            angle: newAngle,
          );
        }
      } else {
        // At the tips, draw leaves!
        final double tipLeafProgress = (overallDepth - depth).clamp(0.0, 1.0);
        if (tipLeafProgress > 0) {
          drawLeafClump(tipLeafProgress);
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(RealisticTreePainter oldDelegate) => oldDelegate.progress != progress;
}
