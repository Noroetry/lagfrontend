import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lagfrontend/theme/app_theme.dart';

/// Reusable popup form / notification panel used across the app.
///
/// Use PopupForm(title: ..., icon: ..., description: ..., actions: [...])
/// You can pass `child` to render custom content inside the panel.
class PopupForm extends StatefulWidget {
  final Widget? icon;
  final String title;
  final String? description;
  final List<Widget>? actions;
  final Widget? child;
  final double? width; // optional fixed width

  const PopupForm({
    super.key,
    this.icon,
    required this.title,
    this.description,
    this.actions,
    this.child,
    this.width,
  });
  @override
  State<PopupForm> createState() => _PopupFormState();
}

class _PopupFormState extends State<PopupForm> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppTheme.popupEntranceDuration);
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double borderRadius = AppTheme.popupBorderRadius;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.width ?? AppTheme.popupMaxWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: AppTheme.popupBlurSigma, sigmaY: AppTheme.popupBlurSigma),
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    padding: AppTheme.popupPadding,
                    decoration: BoxDecoration(
                      color: AppColors.popupBackground,
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: Border.all(color: AppColors.popupBorder, width: 1.0),
                      // Reduced shadow so it doesn't reach the inner text
                      boxShadow: [
                        BoxShadow(color: const Color.fromARGB(80, 0, 0, 0), blurRadius: 8, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Center the header (icon + title) so that the popup
                        // title and icon are always visually centered in the panel.
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.textPrimary, width: 1.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: widget.icon,
                              ),
                              const SizedBox(width: 12),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.textPrimary, width: 1.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                // Title should be centered within its container so the
                                // combined icon+title group is visually centered.
                                child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                              ),
                            ),
                          ],
                        ),
                        if (widget.description != null) ...[
                          const SizedBox(height: 12),
                          Text(widget.description!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                        ],
                        if (widget.child != null) ...[
                          const SizedBox(height: 12),
                          widget.child!,
                        ],
                        if (widget.actions != null && widget.actions!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          // If a single action widget is provided (for example a
                          // Column containing its own button row), render it
                          // directly. Otherwise, render a horizontal row of the
                          // provided action widgets with spacing.
                          if (widget.actions!.length == 1)
                            widget.actions!.first
                            else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ...widget.actions!.expand((w) sync* {
                                  yield w;
                                  yield SizedBox(width: AppTheme.popupActionSpacing);
                                }).toList()..removeLast(),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small action button used in popups.
///
/// Visual behavior:
/// - Small wrapped padding with a subtle border
/// - Elevation for depth; reduces on press to give tactile feel
/// - Turns white while pressed (and text inverts) before executing action
class PopupActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  /// Optional padding override for this button. If null, uses AppTheme.popupButtonPadding.
  final EdgeInsets? padding;

  const PopupActionButton({super.key, required this.label, required this.onPressed, this.padding});

  @override
  State<PopupActionButton> createState() => _PopupActionButtonState();
}

class _PopupActionButtonState extends State<PopupActionButton> {
  bool _pressed = false;

  Future<void> _handleTap() async {
    // Animate to pressed state first so user sees the white flash
    setState(() => _pressed = true);
    // Wait most of the animation duration so the white state is visible
    await Future.delayed(Duration(milliseconds: (AppTheme.popupButtonAnimationDuration.inMilliseconds * 0.6).round()));
    try {
      widget.onPressed();
    } finally {
      // reset visual state after a short delay to allow navigation ripple to show
      if (mounted) setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _pressed ? Colors.white : Colors.transparent;
    final textColor = _pressed ? AppColors.background : AppColors.textPrimary;
    final borderColor = _pressed ? AppColors.background : AppColors.popupBorder;

    final EdgeInsets padding = widget.padding ?? AppTheme.popupButtonPadding;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: AppTheme.popupButtonAnimationDuration,
      curve: Curves.easeInOut,
      child: AnimatedContainer(
        duration: AppTheme.popupButtonAnimationDuration,
        curve: Curves.easeInOut,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          // Slightly tighter corner radius for compact look
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          child: DefaultTextStyle(
            // Use a slightly smaller / tighter label to read as minimal
            style: Theme.of(context).textTheme.labelLarge!.copyWith(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
            child: Center(child: Text(widget.label)),
          ),
        ),
      ),
    );
  }
}
