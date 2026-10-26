import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const AngleDrawerApp());
}

class AngleDrawerApp extends StatelessWidget {
  const AngleDrawerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Angle Maker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AngleDrawerScreen(),
    );
  }
}

class AngleDrawerScreen extends StatefulWidget {
  const AngleDrawerScreen({super.key});

  @override
  State<AngleDrawerScreen> createState() => _AngleDrawerScreenState();
}

class _AngleDrawerScreenState extends State<AngleDrawerScreen> {
  final TextEditingController _controller = TextEditingController(text: '45');
  double? _angle = 45.0;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _drawAngle() {
    final input = _controller.text.trim();

    if (input.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an angle in degrees.';
        _angle = null;
      });
      return;
    }

    final parsed = double.tryParse(input);

    if (parsed == null) {
      setState(() {
        _errorMessage = 'Invalid input. Enter a number between 0 and 360.';
        _angle = null;
      });
      return;
    }

    if (parsed < 0 || parsed > 360) {
      setState(() {
        _errorMessage = 'Please enter an angle between 0° and 360°.';
        _angle = null;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _angle = parsed;
    });
  }

  void _updateAngleFromTouch(Offset touchPosition, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final dx = touchPosition.dx - center.dx;
    final dy = touchPosition.dy - center.dy;

    // Calculate angle in radians counter-clockwise from horizontal right (+X)
    double rad = -math.atan2(dy, dx);
    if (rad < 0) {
      rad += 2 * math.pi;
    }

    // Convert to degrees and round to 1 decimal place
    double degrees = rad * (180.0 / math.pi);
    degrees = double.parse(degrees.toStringAsFixed(1));

    setState(() {
      _angle = degrees;
      _errorMessage = null;
      _controller.text = _formatAngle(degrees);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Angle Maker'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input Section Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Angle in degrees (°)',
                        hintText: 'e.g., 45, 90, 135.5',
                        errorText: _errorMessage,
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.architecture),
                      ),
                      onSubmitted: (_) => _drawAngle(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _drawAngle,
                        icon: const Icon(Icons.draw),
                        label: const Text(
                          'Draw Angle',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Instruction Banner
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, size: 18, color: Colors.indigo.shade700),
                const SizedBox(width: 6),
                Text(
                  'Tip: Drag the handle on the tip of the ray to change the angle!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Canvas Display Card
            Expanded(
              child: Card(
                elevation: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  child: _angle == null
                      ? Center(
                          child: Text(
                            'Enter a valid angle above and tap "Draw Angle".',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          children: [
                            Text(
                              'Angle: ${_formatAngle(_angle!)}°',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Center(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final canvasSize = Size(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    );
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanStart: (details) => _updateAngleFromTouch(
                                        details.localPosition,
                                        canvasSize,
                                      ),
                                      onPanUpdate: (details) => _updateAngleFromTouch(
                                        details.localPosition,
                                        canvasSize,
                                      ),
                                      onTapDown: (details) => _updateAngleFromTouch(
                                        details.localPosition,
                                        canvasSize,
                                      ),
                                      child: CustomPaint(
                                        size: canvasSize,
                                        painter: AnglePainter(angleInDegrees: _angle!),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAngle(double angle) {
    if (angle == angle.truncateToDouble()) {
      return angle.toInt().toString();
    }
    return angle.toStringAsFixed(1);
  }
}

/// Custom Painter to draw extended rays, vertex, arc, and draggable handle
class AnglePainter extends CustomPainter {
  final double angleInDegrees;

  AnglePainter({required this.angleInDegrees});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Extend rays close to the screen/canvas edge while keeping handle knob inside
    const handleRadius = 14.0;
    final maxRadius = math.min(size.width, size.height) / 2;
    final rayLength = math.max(10.0, maxRadius - handleRadius - 6.0);

    // Drawing paints
    final rayPaint = Paint()
      ..color = Colors.indigo
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = Colors.deepOrange
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final arcFillPaint = Paint()
      ..color = Colors.deepOrange.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final vertexPaint = Paint()
      ..color = Colors.indigo.shade900
      ..style = PaintingStyle.fill;

    // Convert degrees to radians
    final angleInRadians = angleInDegrees * (math.pi / 180.0);

    // Ray 1: Base horizontal ray to the right (0°)
    final ray1End = Offset(center.dx + rayLength, center.dy);

    // Ray 2: Rotated ray (-Y direction in Flutter screen coordinates)
    final ray2End = Offset(
      center.dx + rayLength * math.cos(angleInRadians),
      center.dy - rayLength * math.sin(angleInRadians),
    );

    // Arc radius
    final arcRadius = math.max(30.0, rayLength * 0.35);
    final arcRect = Rect.fromCircle(center: center, radius: arcRadius);

    // Sweep angle
    final sweepAngle = -angleInRadians;

    // Draw shaded wedge and arc
    if (angleInDegrees > 0) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(arcRect, 0, sweepAngle, false)
        ..close();
      canvas.drawPath(path, arcFillPaint);

      canvas.drawArc(arcRect, 0, sweepAngle, false, arcPaint);
    }

    // Draw Ray 1 & Ray 2
    canvas.drawLine(center, ray1End, rayPaint);
    _drawArrowHead(canvas, center, ray1End, rayPaint);

    canvas.drawLine(center, ray2End, rayPaint);
    _drawArrowHead(canvas, center, ray2End, rayPaint);

    // Draw vertex point at origin
    canvas.drawCircle(center, 5.0, vertexPaint);

    // Draw draggable handle at the tip of Ray 2
    _drawDraggableHandle(canvas, ray2End, handleRadius);

    // Draw degree text label near the arc
    if (angleInDegrees > 0) {
      _drawAngleLabel(canvas, center, arcRadius, angleInRadians);
    }
  }

  void _drawDraggableHandle(Canvas canvas, Offset position, double radius) {
    // Outer shadow
    canvas.drawCircle(
      position,
      radius + 2.0,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );

    // Outer ring (Indigo)
    canvas.drawCircle(
      position,
      radius,
      Paint()..color = Colors.indigo.shade800,
    );

    // Inner ring (White)
    canvas.drawCircle(
      position,
      radius - 3.5,
      Paint()..color = Colors.white,
    );

    // Core accent dot (Deep Orange)
    canvas.drawCircle(
      position,
      4.5,
      Paint()..color = Colors.deepOrange,
    );
  }

  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Paint paint) {
    const arrowSize = 12.0;
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);

    final path = Path();
    path.moveTo(end.dx, end.dy);
    path.lineTo(
      end.dx - arrowSize * math.cos(angle - math.pi / 6),
      end.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    path.moveTo(end.dx, end.dy);
    path.lineTo(
      end.dx - arrowSize * math.cos(angle + math.pi / 6),
      end.dy - arrowSize * math.sin(angle + math.pi / 6),
    );

    canvas.drawPath(path, paint);
  }

  void _drawAngleLabel(Canvas canvas, Offset center, double arcRadius, double angleInRadians) {
    final labelText = angleInDegrees == angleInDegrees.truncateToDouble()
        ? '${angleInDegrees.toInt()}°'
        : '${angleInDegrees.toStringAsFixed(1)}°';

    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          color: Colors.deepOrange.shade900,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Position label along the midpoint of the arc
    final midAngle = -angleInRadians / 2;
    final labelDistance = arcRadius + 20;
    final labelX = center.dx + labelDistance * math.cos(midAngle) - (textPainter.width / 2);
    final labelY = center.dy + labelDistance * math.sin(midAngle) - (textPainter.height / 2);

    textPainter.paint(canvas, Offset(labelX, labelY));
  }

  @override
  bool shouldRepaint(covariant AnglePainter oldDelegate) {
    return oldDelegate.angleInDegrees != angleInDegrees;
  }
}
