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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
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

class _AngleDrawerScreenState extends State<AngleDrawerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController(text: '45');
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  /// The angle being drawn. Invalid input resets it to 0°.
  double _angle = 45.0;
  String? _errorMessage;
  bool _isDraggingHandle = false;
  bool _isUpdatingFromTouch = false;

  /// Control lock state (unlocked by default when app launches).
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // Horizontal shake sequence
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _triggerLockShake() {
    if (_isLocked) {
      _shakeController.forward(from: 0.0);
    }
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
    if (_isUpdatingFromTouch || _isLocked) return;

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

    // Calculate distance from touch to ray handle
    final distance = (touchPosition - handlePosition).distance;
    final isTouchOnHandle = distance <= kHandleHitRadius;

    if (_isLocked) {
      if (isTouchOnHandle) {
        _triggerLockShake();
      }
      FocusScope.of(context).unfocus();
      return;
    }

    _isDraggingHandle = isTouchOnHandle;

    if (_isDraggingHandle) {
      _updateAngleFromTouch(touchPosition, canvasSize);
    } else {
      // Touching the canvas away from the handle dismisses the keyboard.
      FocusScope.of(context).unfocus();
    }
  }

  void _handleTouchUpdate(Offset touchPosition, Size canvasSize) {
    if (!_isLocked && _isDraggingHandle) {
      _updateAngleFromTouch(touchPosition, canvasSize);
    }
  }

  void _handleTouchEnd() {
    if (_isDraggingHandle) {
      setState(() => _isDraggingHandle = false);
    }
  }

  void _updateAngleFromTouch(Offset touchPosition, Size canvasSize) {
    if (_isLocked) return;

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

    _isUpdatingFromTouch = true;
    if (_controller.text != formatted) {
      _controller.text = formatted;
      _controller.selection = TextSelection.collapsed(offset: formatted.length);
    }

    setState(() {
      _angle = degrees;
      _errorMessage = null;
    });
    _isUpdatingFromTouch = false;
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
          centerTitle: true,
          backgroundColor: colors.inversePrimary,
          title: const Text(
            'Angle Maker',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drawing area: fills remaining height and resizes automatically when keyboard opens.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (details) =>
                          _handleTouchStart(details.localPosition, canvasSize),
                      onPanUpdate: (details) =>
                          _handleTouchUpdate(details.localPosition, canvasSize),
                      onPanEnd: (_) => _handleTouchEnd(),
                      onPanCancel: _handleTouchEnd,
                      child: CustomPaint(
                        size: canvasSize,
                        painter: AnglePainter(
                          angleInDegrees: _angle,
                          isDragging: _isDraggingHandle,
                          isLocked: _isLocked,
                          colors: colors,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Lock Button & Input Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lock button positioned on the right side above the text input field
                  Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        );
                      },
                      child: IconButton.filledTonal(
                        onPressed: () {
                          setState(() {
                            _isLocked = !_isLocked;
                            if (_isLocked) {
                              _isDraggingHandle = false;
                              FocusScope.of(context).unfocus();
                            }
                          });
                        },
                        icon: PadlockIcon(
                          isLocked: _isLocked,
                          size: 26,
                          color: _isLocked ? colors.error : colors.primary,
                        ),
                        tooltip: _isLocked ? 'Unlock controls' : 'Lock controls',
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(10.0),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Text Input Field (triggers lock shake when tapped while locked)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _isLocked ? _triggerLockShake : null,
                    child: TextField(
                      enabled: !_isLocked,
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
                      ),
                      onChanged: _onInputChanged,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Reserved space for error messages (prevents layout shift)
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
// Custom Vector Padlock Icon
// ---------------------------------------------------------------------------

class PadlockIcon extends StatelessWidget {
  final bool isLocked;
  final double size;
  final Color color;

  const PadlockIcon({
    super.key,
    required this.isLocked,
    this.size = 26.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PadlockPainter(isLocked: isLocked, color: color),
    );
  }
}

class _PadlockPainter extends CustomPainter {
  final bool isLocked;
  final Color color;

  _PadlockPainter({required this.isLocked, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shacklePaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.13
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bodyHeight = size.height * 0.50;
    final bodyWidth = size.width * 0.82;
    final bodyLeft = (size.width - bodyWidth) / 2;
    final bodyTop = size.height - bodyHeight;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyLeft, bodyTop, bodyWidth, bodyHeight),
      const Radius.circular(3.0),
    );

    // 1. Draw Lock Body
    canvas.drawRRect(bodyRect, bodyPaint);

    // 2. Draw Keyhole
    final keyholePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, bodyTop + bodyHeight * 0.40),
      size.width * 0.08,
      keyholePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2 - (size.width * 0.04),
        bodyTop + bodyHeight * 0.40,
        size.width * 0.08,
        bodyHeight * 0.32,
      ),
      keyholePaint,
    );

    // 3. Draw Shackle (Clasp)
    final shacklePath = Path();
    final shackleWidth = size.width * 0.46;
    final shackleHeight = size.height * 0.44;

    if (isLocked) {
      // Closed Padlock
      final leftX = size.width / 2 - shackleWidth / 2;
      final rightX = size.width / 2 + shackleWidth / 2;
      final topY = bodyTop - shackleHeight + (shackleWidth / 2);

      shacklePath.moveTo(leftX, bodyTop + 2.0);
      shacklePath.lineTo(leftX, topY);
      shacklePath.addArc(
        Rect.fromLTRB(leftX, bodyTop - shackleHeight, rightX, topY + (shackleWidth / 2)),
        math.pi,
        math.pi,
      );
      shacklePath.lineTo(rightX, bodyTop + 2.0);
    } else {
      // Open Padlock - Shackle centered over the lock body with a shortened right leg
      final shackleLift = size.height * 0.18;
      final leftX = bodyLeft + (bodyWidth - shackleWidth) / 2;
      final rightX = leftX + shackleWidth;
      final topY = bodyTop - shackleHeight - shackleLift;

      shacklePath.moveTo(leftX, bodyTop + 2.0);
      shacklePath.lineTo(leftX, topY + (shackleWidth / 2));
      shacklePath.addArc(
        Rect.fromLTRB(leftX, topY, rightX, topY + shackleWidth),
        math.pi,
        math.pi,
      );
      // Shortened right leg: includes a small vertical section below the arc
      shacklePath.lineTo(rightX, topY + (shackleWidth * 0.65));
    }

    canvas.drawPath(shacklePath, shacklePaint);
  }

  @override
  bool shouldRepaint(covariant _PadlockPainter oldDelegate) {
    return oldDelegate.isLocked != isLocked || oldDelegate.color != color;
  }
}

// ---------------------------------------------------------------------------
// Painter: rays, vertex, arc, label, and the draggable handle
// ---------------------------------------------------------------------------

class AnglePainter extends CustomPainter {
  final double angleInDegrees;
  final bool isDragging;
  final bool isLocked;
  final ColorScheme colors;

  AnglePainter({
    required this.angleInDegrees,
    required this.colors,
    this.isDragging = false,
    this.isLocked = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rayLength = rayLengthFor(size);
    final radians = degreesToRadians(angleInDegrees);

    final rayPaint = Paint()
      ..color = isLocked ? colors.outline : colors.primary.withValues(alpha: 0.50)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = isLocked ? colors.outline : colors.tertiary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final arcFillPaint = Paint()
      ..color = (isLocked ? colors.outline : colors.tertiary).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final vertexPaint = Paint()
      ..color = isLocked ? colors.outline : colors.onSurface
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
    // Soft shadow / glow.
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
      Paint()..color = isLocked ? colors.outline : (isDragging ? colors.tertiary : colors.primary),
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
      Paint()..color = isLocked ? colors.outline : colors.tertiary,
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
    final labelText = '${formatAngle(angleInDegrees)}°';
    final textColor = isLocked ? colors.outline : Colors.indigo.shade900;

    // White outline halo for crystal-clear legibility over ray lines
    final strokePainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..color = colors.surface,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Place the label just outside the arc, halfway around it.
    final labelCenter = pointOnCircle(center, arcRadius + 28, radians / 2);
    final offset = labelCenter - Offset(textPainter.width / 2, textPainter.height / 2);

    // Paint outline halo first, then dark text on top
    strokePainter.paint(canvas, offset);
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant AnglePainter oldDelegate) {
    return oldDelegate.angleInDegrees != angleInDegrees ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.isLocked != isLocked ||
        oldDelegate.colors != colors;
  }
}
