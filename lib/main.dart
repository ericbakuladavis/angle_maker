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
  bool _isDraggingHandle = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onInputChanged(String text) {
    final input = text.trim();

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

  void _handleTouchStart(Offset touchPosition, Size canvasSize) {
    if (_angle == null) return;

    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final maxRadius = math.min(canvasSize.width, canvasSize.height) / 2;
    final rayLength = math.max(10.0, maxRadius - 18.0);

    final angleInRadians = _angle! * (math.pi / 180.0);
    final handlePosition = Offset(
      center.dx + rayLength * math.cos(angleInRadians),
      center.dy - rayLength * math.sin(angleInRadians),
    );

    // Enable dragging if tap is within 36 pixels of the tip handle circle
    final distance = (touchPosition - handlePosition).distance;
    if (distance <= 36.0) {
      _isDraggingHandle = true;
      _updateAngleFromTouch(touchPosition, canvasSize);
    } else {
      _isDraggingHandle = false;
      // Dismiss soft keyboard when tapping canvas outside the handle
      FocusScope.of(context).unfocus();
    }
  }

  void _handleTouchUpdate(Offset touchPosition, Size canvasSize) {
    if (_isDraggingHandle) {
      _updateAngleFromTouch(touchPosition, canvasSize);
    }
  }

  void _handleTouchEnd() {
    if (_isDraggingHandle) {
      setState(() {
        _isDraggingHandle = false;
      });
    }
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

    final formatted = _formatAngle(degrees);

    setState(() {
      _angle = degrees;
      _errorMessage = null;
      if (_controller.text != formatted) {
        _controller.text = formatted;
        _controller.selection = TextSelection.collapsed(offset: formatted.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping anywhere outside the input field
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 46.0,
          titleSpacing: 16.0,
          centerTitle: false,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Angle Maker',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Flexible(
                child: Text(
                  'Drag the circle or enter an angle.',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.indigo.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Canvas Display Area (Fills remaining height and scales automatically when keyboard opens)
              Expanded(
                child: _angle == null
                    ? Center(
                        child: Text(
                          'Enter a valid angle below (0° – 360°).',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final canvasSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (details) => _handleTouchStart(
                              details.localPosition,
                              canvasSize,
                            ),
                            onPanUpdate: (details) => _handleTouchUpdate(
                              details.localPosition,
                              canvasSize,
                            ),
                            onPanEnd: (_) => _handleTouchEnd(),
                            onPanCancel: () => _handleTouchEnd(),
                            onTapDown: (details) => _handleTouchStart(
                              details.localPosition,
                              canvasSize,
                            ),
                            onTapUp: (_) => _handleTouchEnd(),
                            child: CustomPaint(
                              size: canvasSize,
                              painter: AnglePainter(
                                angleInDegrees: _angle!,
                                isDragging: _isDraggingHandle,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 8),

              // Real-time Input Section Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Angle in degrees (°)',
                      errorText: _errorMessage,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      suffixIcon: const Icon(Icons.architecture),
                    ),
                    onChanged: _onInputChanged,
                  ),
                ),
              ),
            ],
          ),
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
  final bool isDragging;

  AnglePainter({required this.angleInDegrees, this.isDragging = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Calculate max radius based on current size (width & height), so drawing auto-scales smoothly
    final handleRadius = isDragging ? 16.0 : 14.0;
    final maxRadius = math.min(size.width, size.height) / 2;
    final rayLength = math.max(10.0, maxRadius - 18.0);

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
    // Outer shadow (larger when dragging)
    canvas.drawCircle(
      position,
      radius + (isDragging ? 4.0 : 2.0),
      Paint()
        ..color = isDragging ? Colors.deepOrange.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // Outer ring (Indigo or Deep Orange when dragging)
    canvas.drawCircle(
      position,
      radius,
      Paint()..color = isDragging ? Colors.deepOrange.shade800 : Colors.indigo.shade800,
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
      isDragging ? 5.5 : 4.5,
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
    return oldDelegate.angleInDegrees != angleInDegrees ||
        oldDelegate.isDragging != isDragging;
  }
}
