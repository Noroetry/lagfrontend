import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A minimalist circular countdown widget that shows time remaining
/// until quest expiration. The circle fills with red as time runs out.
///
/// - `dateExpirationRaw` can be either ISO-8601 string or DateTime object
/// - `durationMinutes` is the total duration in minutes for calculating progress
class CircularQuestCountdown extends StatefulWidget {
  final dynamic dateExpirationRaw;
  final int? durationMinutes;
  final double size;

  const CircularQuestCountdown({
    super.key,
    required this.dateExpirationRaw,
    this.durationMinutes,
    this.size = 100,
  });

  @override
  State<CircularQuestCountdown> createState() => _CircularQuestCountdownState();
}

class _CircularQuestCountdownState extends State<CircularQuestCountdown> {
  Timer? _ticker;
  double _progress = 0.0; // 0.0 = just started, 1.0 = expired
  DateTime? _expiresAt;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _parseDates();
    _update();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  DateTime? _parse(dynamic raw) {
    try {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.parse(raw);
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    } catch (_) {}
    return null;
  }

  void _parseDates() {
    _expiresAt = _parse(widget.dateExpirationRaw);
    
    // Calculate start time from duration if provided
    if (widget.durationMinutes != null && _expiresAt != null) {
      _startedAt = _expiresAt!.subtract(Duration(minutes: widget.durationMinutes!));
    }
  }

  void _update() {
    if (!mounted) return;
    
    final now = DateTime.now();
    if (_expiresAt == null) {
      setState(() => _progress = 1.0); // Show as expired
      return;
    }

    final remaining = _expiresAt!.difference(now);
    
    // If expired, show full circle
    if (remaining.isNegative) {
      setState(() => _progress = 1.0);
      return;
    }

    // Calculate progress (0.0 = start, 1.0 = expired)
    // Progress increases as time passes (circle fills up as deadline approaches)
    double prog = 0.0;
    if (_startedAt != null) {
      final total = _expiresAt!.difference(_startedAt!);
      if (total.inMilliseconds > 0) {
        final elapsed = now.difference(_startedAt!);
        prog = elapsed.inMilliseconds / total.inMilliseconds;
        prog = prog.clamp(0.0, 1.0);
      } else {
        // Si total es 0 o negativo, mostrar como casi expirado
        prog = 0.95;
      }
    } else {
      // If we don't have start time, calculate based on remaining time
      // For a daily quest (24h), if 5h remain, we should show ~79% filled (19h elapsed / 24h total)
      if (remaining.inHours < 1) {
        // Less than 1 hour: show 95-100% filled
        prog = 0.95 + (1.0 - (remaining.inMinutes / 60.0)) * 0.05;
      } else if (remaining.inHours < 6) {
        // 1-6 hours remaining: show 75-95% filled
        prog = 0.75 + (1.0 - (remaining.inHours / 6.0)) * 0.20;
      } else if (remaining.inHours < 24) {
        // 6-24 hours remaining: show 0-75% filled
        prog = (1.0 - (remaining.inHours / 24.0)) * 0.75;
      } else {
        // More than 24 hours: show minimal progress
        prog = 0.0;
      }
      prog = prog.clamp(0.0, 1.0);
    }

    setState(() => _progress = prog);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _CircularCountdownPainter(
            progress: _progress,
            backgroundColor: Colors.grey[800]!,
            progressColor: Colors.red,
          ),
        ),
      ),
    );
  }
}

class _CircularCountdownPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  _CircularCountdownPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.15; // 15% of radius for the ring thickness

    // Draw background circle (unfilled part)
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Draw progress arc (fills clockwise from top)
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2; // Start from top (12 o'clock)
      final sweepAngle = 2 * math.pi * progress; // Sweep clockwise

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularCountdownPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor;
  }
}
