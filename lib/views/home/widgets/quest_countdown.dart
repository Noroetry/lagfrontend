import 'dart:async';
import 'package:flutter/material.dart';

/// Small widget that displays a live countdown to [dateExpirationRaw].
///
/// - `dateExpirationRaw` can be either ISO-8601 string or DateTime object.
/// - `durationMinutes` is the total duration in minutes. If provided, the start
///   time will be calculated as (dateExpiration - durationMinutes).
/// - `dateReadRaw` (deprecated) can be provided as fallback if durationMinutes
///   is not available.
class QuestCountdown extends StatefulWidget {
  final dynamic dateExpirationRaw;
  final dynamic dateReadRaw;
  final int? durationMinutes;

  const QuestCountdown({
    super.key,
    this.dateExpirationRaw,
    this.dateReadRaw,
    this.durationMinutes,
  });

  @override
  State<QuestCountdown> createState() => _QuestCountdownState();
}

class _QuestCountdownState extends State<QuestCountdown> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  double _fraction = 0.0;
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
      // Don't convert to UTC - Dart handles timezone automatically
      // when comparing UTC dates with local DateTime.now()
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.parse(raw); // Detects 'Z' suffix automatically
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    } catch (_) {}
    return null;
  }

  void _parseDates() {
    _expiresAt = _parse(widget.dateExpirationRaw);
    
    // Priority 1: If durationMinutes is provided, calculate start time
    if (widget.durationMinutes != null && _expiresAt != null) {
      _startedAt = _expiresAt!.subtract(Duration(minutes: widget.durationMinutes!));
    } 
    // Priority 2: Fall back to dateReadRaw if available
    else {
      _startedAt = _parse(widget.dateReadRaw);
    }
  }

  void _update() {
    final now = DateTime.now(); // Local time - Dart handles timezone conversion automatically
    if (_expiresAt == null) {
      setState(() {
        _remaining = Duration.zero;
        _fraction = 0.0;
      });
      return;
    }

    final rem = _expiresAt!.difference(now);
    final total = (_startedAt != null)
        ? _expiresAt!.difference(_startedAt!)
        : null;

    final clamped = rem.isNegative ? Duration.zero : rem;
    double frac = 0.0;
    if (total != null && total.inMilliseconds > 0) {
      // Calculate fraction of time REMAINING (not elapsed)
      // So the bar shows green for time left and drains as time passes
      frac = clamped.inMilliseconds / total.inMilliseconds;
      if (frac < 0) frac = 0.0;
      if (frac > 1) frac = 1.0;
    }

    setState(() {
      _remaining = clamped;
      _fraction = frac;
    });
  }

  String _format(Duration d) {
    if (d.inSeconds <= 0) return '00:00:00';
    final days = d.inDays;
    final hours = d.inHours.remainder(24).toString().padLeft(2, '0');
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (days > 0) return '${days}d $hours:$mins:$secs';
    return '$hours:$mins:$secs';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _format(_remaining);
    return SizedBox(
      width: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large countdown text centered
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          // Animate progress changes smoothly
          SizedBox(
            height: 8,
            child: _startedAt != null
                ? TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: _fraction, end: _fraction),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) => LinearProgressIndicator(
                      value: value.clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      color: Colors.green[400],
                      minHeight: 8,
                    ),
                  )
                : LinearProgressIndicator(
                    value: null,
                    backgroundColor: Colors.white12,
                    color: Colors.green[400],
                    minHeight: 8,
                  ),
          ),
        ],
      ),
    );
  }
}
