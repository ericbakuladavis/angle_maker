import 'dart:math' as math;
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Constants and small helpers shared by the screen and the painter
// ---------------------------------------------------------------------------

/// Gap between the ray tips and the edge of the drawing area.
const double kRayMargin = 18.0;
const double kMinRayLength = 10.0;

/// How close (in pixels) a touch must be to the handle to start a drag.
const double kHandleHitRadius = 36.0;
const double kHandleRadius = 14.0;
const double kHandleRadiusDragging = 16.0;

/// The arc is this fraction of the ray length, but never smaller than the min.
const double kArcRadiusFraction = 0.35;
const double kMinArcRadius = 30.0;

const double kMaxAngle = 360.0;

/// Length of both rays for a drawing area of the given size.
/// Used by the painter AND the touch handling so they always agree.
double rayLengthFor(Size size) {
  return math.max(kMinRayLength, math.min(size.width, size.height) / 2 - kRayMargin);
}

/// A point on a circle, with angles measured counter-clockwise from the
/// right (the way angles are drawn in math). Screen y points down, so we
/// subtract the sin part.
Offset pointOnCircle(Offset center, double radius, double radians) {
  return Offset(
    center.dx + radius * math.cos(radians),
    center.dy - radius * math.sin(radians),
  );
}

double degreesToRadians(double degrees) => degrees * (math.pi / 180.0);

/// 45.0 -> "45", 42.57 -> "42.6"
String formatAngle(double angle) {
  if (angle == angle.truncateToDouble()) {
    return angle.toInt().toString();
  }
  return angle.toStringAsFixed(1);
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

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

  /// The angle being drawn. Invalid input resets it to 0°.
  double _angle = 45.0;
  String? _errorMessage;
  bool _isDraggingHandle = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Typing in the text field
  // -------------------------------------------------------------------------

  /// Shows an error message under the field and resets the drawing to 0°.
  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _angle = 0.0;
    });
  }

  void _onInputChanged(String text) {
    // Accept "4,5" as well as "4.5" (some phone keyboards show a comma).
    final input = text.trim().replaceAll(',', '.');

    if (input.isEmpty) {
      _showError('Please enter an angle in degrees.');
      return;
    }

    final parsed = double.tryParse(input);

    if (parsed == null || !parsed.isFinite) {
      _showError('Invalid input. Enter a number between 0 and 360.');
      return;
    }

    if (parsed < 0 || parsed > kMaxAngle) {
      _showError('Please enter an angle between 0° and 360°.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _angle = parsed;
    });
  }

  // -------------------------------------------------------------------------
  // Dragging the handle on the canvas
  // -------------------------------------------------------------------------

  void _handleTouchStart(Offset touchPosition, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final handlePosition = pointOnCircle(
      center,
      rayLengthFor(canvasSize),
      degreesToRadians(_angle),
    );

    // Only start dragging if the touch lands on (or near) the handle.
    final distance = (touchPosition - handlePosition).distance;
    _isDraggingHandle = distance <= kHandleHitRadius;

    if (_isDraggingHandle) {
      _updateAngleFromTouch(touchPosition, canvasSize);
    } else {
      // Touching the canvas away from the handle dismisses the keyboard.
      // (The canvas has its own tap handlers, so the screen-wide tap handler
      // below never sees these touches. That's why this is needed here.)
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
      setState(() => _isDraggingHandle = false);
    }
  }

  void _updateAngleFromTouch(Offset touchPosition, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final dx = touchPosition.dx - center.dx;
    final dy = touchPosition.dy - center.dy;

    // Angle counter-clockwise from the right, in the range 0 to 2*pi.
    double radians = -math.atan2(dy, dx);
    if (radians < 0) {
      radians += 2 * math.pi;
    }

    // Round to 1 decimal place.
    final degrees = double.parse((radians * 180.0 / math.pi).toStringAsFixed(1));
    final formatted = formatAngle(degrees);

    // Updating the controller from code does NOT trigger onChanged,
    // so the text field and the drawing stay in sync without any flags.
    if (_controller.text != formatted) {
      _controller.text = formatted;
      _controller.selection = TextSelection.collapsed(offset: formatted.length);
    }

    setState(() {
      _angle = degrees;
      _errorMessage = null;
    });
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      // Tapping anywhere outside the text field dismisses the keyboard.
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 46.0,
          titleSpacing: 16.0,
          centerTitle: false,
          backgroundColor: colors.inversePrimary,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Angle Maker',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Flexible(
                child: Text(
                  'Drag the circle or enter an angle',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.primary,
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
              // Drawing area: fills the remaining height and resizes
              // automatically when the keyboard opens.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) =>
                          _handleTouchStart(details.localPosition, canvasSize),
                      onPanUpdate: (details) =>
                          _handleTouchUpdate(details.localPosition, canvasSize),
                      onPanEnd: (_) => _handleTouchEnd(),
                      onPanCancel: _handleTouchEnd,
                      onTapDown: (details) =>
                          _handleTouchStart(details.localPosition, canvasSize),
                      onTapUp: (_) => _handleTouchEnd(),
                      child: CustomPaint(
                        size: canvasSize,
                        painter: AnglePainter(
                          angleInDegrees: _angle,
                          isDragging: _isDraggingHandle,
                          colors: colors,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Angle in degrees (°)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 12.0,
                      ),
                      suffixIcon: Icon(Icons.architecture),
                    ),
                    onChanged: _onInputChanged,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 20.0,
                    child: Text(
                      _errorMessage ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.error,
                        fontSize: 12.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter: rays, vertex, arc, label, and the draggable handle
// ---------------------------------------------------------------------------

class AnglePainter extends CustomPainter {
  final double angleInDegrees;
  final bool isDragging;
  final ColorScheme colors;

  AnglePainter({
    required this.angleInDegrees,
    required this.colors,
    this.isDragging = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rayLength = rayLengthFor(size);
    final radians = degreesToRadians(angleInDegrees);

    final rayPaint = Paint()
      ..color = colors.primary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = colors.tertiary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final arcFillPaint = Paint()
      ..color = colors.tertiary.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final vertexPaint = Paint()
      ..color = colors.onSurface
      ..style = PaintingStyle.fill;

    // Ray 1: horizontal, pointing right. Ray 2: rotated by the angle.
    final ray1End = pointOnCircle(center, rayLength, 0);
    final ray2End = pointOnCircle(center, rayLength, radians);

    // Arc between the rays. Negative sweep = counter-clockwise on screen.
    final arcRadius = math.max(kMinArcRadius, rayLength * kArcRadiusFraction);
    final arcRect = Rect.fromCircle(center: center, radius: arcRadius);
    final sweepAngle = -radians;

    if (angleInDegrees > 0) {
      final wedge = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(arcRect, 0, sweepAngle, false)
        ..close();
      canvas.drawPath(wedge, arcFillPaint);
      canvas.drawArc(arcRect, 0, sweepAngle, false, arcPaint);
    }

    canvas.drawLine(center, ray1End, rayPaint);
    _drawArrowHead(canvas, center, ray1End, rayPaint);

    canvas.drawLine(center, ray2End, rayPaint);
    _drawArrowHead(canvas, center, ray2End, rayPaint);

    canvas.drawCircle(center, 5.0, vertexPaint);

    _drawDraggableHandle(
      canvas,
      ray2End,
      isDragging ? kHandleRadiusDragging : kHandleRadius,
    );

    if (angleInDegrees > 0) {
      _drawAngleLabel(canvas, center, arcRadius, radians);
    }
  }

  void _drawDraggableHandle(Canvas canvas, Offset position, double radius) {
    // Soft shadow / glow (stronger while dragging).
    canvas.drawCircle(
      position,
      radius + (isDragging ? 4.0 : 2.0),
      Paint()
        ..color = isDragging
            ? colors.tertiary.withValues(alpha: 0.3)
            : colors.shadow.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // Outer ring.
    canvas.drawCircle(
      position,
      radius,
      Paint()..color = isDragging ? colors.tertiary : colors.primary,
    );

    // Inner ring.
    canvas.drawCircle(
      position,
      radius - 3.5,
      Paint()..color = colors.surface,
    );

    // Core dot.
    canvas.drawCircle(
      position,
      isDragging ? 5.5 : 4.5,
      Paint()..color = colors.tertiary,
    );
  }

  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Paint paint) {
    const arrowSize = 12.0;
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);

    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle - math.pi / 6),
        end.dy - arrowSize * math.sin(angle - math.pi / 6),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle + math.pi / 6),
        end.dy - arrowSize * math.sin(angle + math.pi / 6),
      );

    canvas.drawPath(path, paint);
  }

  void _drawAngleLabel(
    Canvas canvas,
    Offset center,
    double arcRadius,
    double radians,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${formatAngle(angleInDegrees)}°',
        style: TextStyle(
          color: colors.tertiary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Place the label just outside the arc, halfway around it.
    final labelCenter = pointOnCircle(center, arcRadius + 20, radians / 2);
    textPainter.paint(
      canvas,
      labelCenter - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant AnglePainter oldDelegate) {
    return oldDelegate.angleInDegrees != angleInDegrees ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.colors != colors;
  }
}
