import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const ProtractorApp());

class ProtractorApp extends StatelessWidget {
  const ProtractorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Protractor',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const ProtractorPage(),
    );
  }
}

const double kHandleRadius = 16;
const double kHitRadius = 40;

/// Formats an angle with up to 2 decimals, dropping trailing zeros.
String formatAngle(double v) {
  var s = v.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  s = s.replaceFirst(RegExp(r'\.$'), '');
  return s;
}

/// Point where a ray at [deg] (0 = up, clockwise) meets the edge of [size],
/// inset so the whole handle circle stays visible.
Offset handlePosition(Size size, double deg) {
  final c = Offset(size.width / 2, size.height / 2);
  final rad = deg * math.pi / 180;
  final dx = math.sin(rad);
  final dy = -math.cos(rad);
  final m = kHandleRadius + 4;
  var t = double.infinity;
  if (dx > 1e-9) {
    t = math.min(t, (size.width - m - c.dx) / dx);
  } else if (dx < -1e-9) {
    t = math.min(t, (m - c.dx) / dx);
  }
  if (dy > 1e-9) {
    t = math.min(t, (size.height - m - c.dy) / dy);
  } else if (dy < -1e-9) {
    t = math.min(t, (m - c.dy) / dy);
  }
  t = math.max(t, 0);
  return c + Offset(dx * t, dy * t);
}

class ProtractorPage extends StatefulWidget {
  const ProtractorPage({super.key});

  @override
  State<ProtractorPage> createState() => _ProtractorPageState();
}

class _ProtractorPageState extends State<ProtractorPage>
    with SingleTickerProviderStateMixin {
  double _start = 0; // direction of ray 1 in degrees (0 = straight up)
  double _angle = 45; // clockwise angle from ray 1 to ray 2
  bool _locked = false;
  int? _dragging; // 0 = ray 1 handle, 1 = ray 2 handle
  Size _size = Size.zero;

  final _controller = TextEditingController(text: '45');
  final _focus = FocusNode();
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _focus.addListener(() {
      // Tidy up the text (e.g. empty or "5.") when the field loses focus.
      if (!_focus.hasFocus) setState(_syncText);
    });
  }

  @override
  void dispose() {
    _shake.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _syncText() {
    final t = formatAngle(_angle);
    _controller.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  double _norm(double x) => ((x * 10).round() / 10) % 360;

  void _shakeLock() => _shake.forward(from: 0);

  void _toggleLock() {
    setState(() {
      _locked = !_locked;
      _dragging = null;
      if (_locked) _focus.unfocus();
    });
  }

  void _onTextChanged(String s) {
    // Empty field (or just a ".") means 0 degrees.
    if (s.isEmpty || s == '.') {
      setState(() => _angle = 0);
      return;
    }
    final v = double.tryParse(s);
    if (v == null) return;
    if (v > 360) {
      setState(() {
        _angle = 360;
        _syncText();
      });
    } else {
      setState(() => _angle = v);
    }
  }

  // Shake the lock if a handle is touched while locked.
  void _onCanvasPointerDown(PointerDownEvent e) {
    if (!_locked) return;
    final a = handlePosition(_size, _start);
    final b = handlePosition(_size, _start + _angle);
    if ((e.localPosition - a).distance <= kHitRadius ||
        (e.localPosition - b).distance <= kHitRadius) {
      _shakeLock();
    }
  }

  void _onPanStart(DragStartDetails d) {
    if (_locked) return;
    final a = handlePosition(_size, _start);
    final b = handlePosition(_size, _start + _angle);
    final da = (d.localPosition - a).distance;
    final db = (d.localPosition - b).distance;
    if (db <= kHitRadius && db <= da) {
      _dragging = 1;
    } else if (da <= kHitRadius) {
      _dragging = 0;
    } else {
      _dragging = null;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_locked || _dragging == null) return;
    final c = Offset(_size.width / 2, _size.height / 2);
    final p = d.localPosition - c;
    final deg = (math.atan2(p.dx, -p.dy) * 180 / math.pi) % 360;
    setState(() {
      if (_dragging == 1) {
        _angle = _norm(deg - _start);
      } else {
        final end = _start + _angle;
        _start = deg;
        _angle = _norm(end - deg);
      }
      _syncText();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Banner
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: const Color(0xFF1A1A1A),
              child: Row(
                children: [
                  const Text(
                    'Protractor',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _shake,
                    builder: (context, child) {
                      final t = _shake.value;
                      final dx = math.sin(t * math.pi * 6) * 8 * (1 - t);
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: IconButton(
                      tooltip: _locked ? 'Unlock' : 'Lock',
                      onPressed: _toggleLock,
                      icon: Icon(
                        _locked ? Icons.lock : Icons.lock_open,
                        color: _locked ? Colors.red : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Drawing area (shrinks when the keyboard opens)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _size = Size(constraints.maxWidth, constraints.maxHeight);
                  return Listener(
                    onPointerDown: _onCanvasPointerDown,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!_locked) _focus.unfocus();
                      },
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: (_) => _dragging = null,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _ProtractorPainter(_start, _angle, _locked),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Text input (touching it while locked shakes the lock)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Listener(
                onPointerDown: (_) {
                  if (_locked) _shakeLock();
                },
                child: AbsorbPointer(
                  absorbing: _locked,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: !_locked,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,3}\.?\d{0,2}')),
                    ],
                    onChanged: _onTextChanged,
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Angle (0–360)',
                      suffixText: '°',
                      filled: true,
                      fillColor: Color(0xFF1A1A1A),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProtractorPainter extends CustomPainter {
  final double start;
  final double angle;
  final bool locked;

  _ProtractorPainter(this.start, this.angle, this.locked);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final color = locked ? Colors.grey : Colors.white;
    final a = handlePosition(size, start);
    final b = handlePosition(size, start + angle);

    // Arc between the rays
    final arcR = (math.min(size.width, size.height) * 0.15).clamp(24.0, 70.0);
    final arcRect = Rect.fromCircle(center: c, radius: arcR);
    final startRad = -math.pi / 2 + start * math.pi / 180;
    final sweepRad = angle * math.pi / 180;
    canvas.drawArc(
      arcRect,
      startRad,
      sweepRad,
      true,
      Paint()..color = const Color(0x40FFFFFF),
    );
    canvas.drawArc(
      arcRect,
      startRad,
      sweepRad,
      false,
      Paint()
        ..color = Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Rays
    final rayPaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, a, rayPaint);
    canvas.drawLine(c, b, rayPaint);

    // Center dot
    canvas.drawCircle(c, 5, Paint()..color = color);

    // Handles
    final fill = Paint()..color = color;
    final border = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final p in [a, b]) {
      canvas.drawCircle(p, kHandleRadius, fill);
      canvas.drawCircle(p, kHandleRadius - 1.5, border);
    }

    // Angle label, just outside the midpoint of the arc
    _paintLabel(canvas, size, c, arcR);
  }

  void _paintLabel(Canvas canvas, Size size, Offset c, double arcR) {
    final text = '${formatAngle(angle)}°';
    const fontSize = 16.0;

    final halo = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final fill = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Direction of the arc's midpoint (0 = up, clockwise)
    final midRad = (start + angle / 2) * math.pi / 180;
    final dx = math.sin(midRad);
    final dy = -math.cos(midRad);

    // Distance from the text's center to its edge along that direction,
    // so the whole label sits outside the arc with a small gap.
    final halfW = fill.width / 2;
    final halfH = fill.height / 2;
    final tx = dx.abs() < 1e-9 ? double.infinity : halfW / dx.abs();
    final ty = dy.abs() < 1e-9 ? double.infinity : halfH / dy.abs();
    final reach = math.min(tx, ty);

    final dist = arcR + 6 + reach;
    var center = c + Offset(dx * dist, dy * dist);

    // Keep the label inside the drawing area
    center = Offset(
      center.dx.clamp(halfW + 2, math.max(halfW + 2, size.width - halfW - 2)),
      center.dy.clamp(halfH + 2, math.max(halfH + 2, size.height - halfH - 2)),
    );

    final topLeft = center - Offset(halfW, halfH);
    halo.paint(canvas, topLeft);
    fill.paint(canvas, topLeft);
  }

  @override
  bool shouldRepaint(_ProtractorPainter old) =>
      old.start != start || old.angle != angle || old.locked != locked;
}