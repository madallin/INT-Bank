import 'package:flutter/material.dart';

import '../core/utils/haptic_feedback_helper.dart';
import '../theme/app_tokens.dart';

/// The round badge on a finished payment: the circle pops in, a ring spreads out and the
/// check is drawn. With "remove animations" on, it appears already finished. Buzzes once
/// when it appears if [haptic] is set.
class SuccessBadge extends StatefulWidget
{
  const SuccessBadge({super.key, this.size = 88, this.haptic = true, this.icon});

  final double size;
  final bool haptic;

  /// A different glyph than the drawn check (e.g. a calendar for scheduled payments);
  /// it fades in instead of being drawn.
  final IconData? icon;

  @override
  State<SuccessBadge> createState() => _SuccessBadgeState();
}

class _SuccessBadgeState extends State<SuccessBadge> with SingleTickerProviderStateMixin
{
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _started = false;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    if(_started) return;
    _started = true;
    if(MediaQuery.maybeDisableAnimationsOf(context) ?? false)
    {
      _controller.value = 1;
    }
    else
    {
      _controller.forward();
    }
    if(widget.haptic) HapticFeedbackHelper.success();
  }

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final c = context.colors;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final pop = Curves.elasticOut.transform((t / 0.55).clamp(0.0, 1.0));
          final ring = Curves.easeOut.transform(((t - 0.15) / 0.85).clamp(0.0, 1.0));
          final draw = Curves.easeInOut.transform(((t - 0.4) / 0.5).clamp(0.0, 1.0));
          return SizedBox.square(
            dimension: widget.size * 1.5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: (1 - ring).clamp(0.0, 1.0),
                  child: Container(
                    width: widget.size * (1 + 0.5 * ring),
                    height: widget.size * (1 + 0.5 * ring),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.brand, width: 2)),
                  ),
                ),
                Transform.scale(
                  scale: pop,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [c.heroStart, c.heroEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    child: widget.icon != null
                        ? Opacity(opacity: draw, child: Icon(widget.icon, size: widget.size * 0.5, color: Colors.white))
                        : CustomPaint(painter: _CheckPainter(draw)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter
{
  _CheckPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size)
  {
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.73, size.height * 0.35);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
