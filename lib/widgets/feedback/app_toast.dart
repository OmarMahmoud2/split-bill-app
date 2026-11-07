import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:split_bill_app/theme/app_haptics.dart';
import 'package:split_bill_app/theme/app_motion.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/theme/app_spacing.dart';
import 'package:split_bill_app/theme/app_typography.dart';
import 'package:split_bill_app/theme/app_icons.dart';

enum AppToastType { success, info, warning, error }

enum AppToastPosition { top, bottom }

/// Handle to a visible toast.
class AppToastController {
  AppToastController._();

  _AppToastHostState? _state;
  bool _removed = false;

  bool get isShowing {
    final state = _state;
    if (_removed) return false;
    return state == null || (state.mounted && !state._closing);
  }

  /// Animates the toast out.
  Future<void> dismiss() async {
    final state = _state;
    if (state == null || !state.mounted) {
      if (identical(AppToast._current, this)) AppToast.hide();
      _removed = true;
      return;
    }
    await state._close();
  }
}

/// v3 toast: an ink pill with a status icon, one line of text and an
/// optional action. Auto-dismisses, swipes away, and is announced to screen
/// readers (live region + announcement). One toast at a time: showing a new
/// one replaces the current one.
///
/// ```dart
/// AppToast.show(context, message: 'bill_saved'.tr(),
///     type: AppToastType.success);
/// AppToast.show(context, message: 'could_not_send'.tr(),
///     type: AppToastType.error, actionLabel: 'feedback_try_again'.tr(),
///     onAction: _send, position: AppToastPosition.top);
/// ```
class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static AppToastController? _current;

  /// The toast on screen, if any.
  static AppToastController? get current => _current;

  static AppToastController show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    AppToastPosition position = AppToastPosition.bottom,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = AppMotion.toastVisible,
    bool haptic = true,
  }) {
    hide();
    final overlay = Overlay.of(context, rootOverlay: true);
    final controller = AppToastController._();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AppToastHost(
        message: message,
        type: type,
        position: position,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        controller: controller,
        onClosed: () {
          controller._removed = true;
          if (identical(_entry, entry)) {
            _entry = null;
            _current = null;
          }
          _remove(entry);
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    if (haptic) {
      switch (type) {
        case AppToastType.success:
          AppHaptics.success();
        case AppToastType.warning:
          AppHaptics.warning();
        case AppToastType.error:
          AppHaptics.error();
        case AppToastType.info:
          break;
      }
    }
    _current = controller;
    return controller;
  }

  /// Removes the current toast immediately (no animation).
  static void hide() {
    _current?._removed = true;
    final entry = _entry;
    _entry = null;
    _current = null;
    if (entry != null) _remove(entry);
  }

  static final Expando<bool> _removed = Expando<bool>('removed');

  /// Removes [entry] once, even if it has not built a frame yet.
  static void _remove(OverlayEntry entry) {
    if (_removed[entry] ?? false) return;
    _removed[entry] = true;
    entry.remove();
  }
}

class _AppToastHost extends StatefulWidget {
  const _AppToastHost({
    required this.message,
    required this.type,
    required this.position,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.controller,
    required this.onClosed,
  });

  final String message;
  final AppToastType type;
  final AppToastPosition position;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final AppToastController controller;
  final VoidCallback onClosed;

  @override
  State<_AppToastHost> createState() => _AppToastHostState();
}

class _AppToastHostState extends State<_AppToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _closing = false;
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.slow);
    widget.controller._state = this;
    _timer = Timer(widget.duration, _close);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = AppMotion.reduceMotion(context);
    _controller.duration = reduce ? AppMotion.reducedCrossfade : AppMotion.slow;
    _controller.reverseDuration = reduce
        ? AppMotion.reducedCrossfade
        : AppMotion.medium;
    if (!_announced) {
      _announced = true;
      _controller.forward();
      final view = View.maybeOf(context);
      if (view != null) {
        SemanticsService.sendAnnouncement(
          view,
          '${_typeLabel(widget.type)}: ${widget.message}',
          Directionality.of(context),
          assertiveness: widget.type == AppToastType.error
              ? Assertiveness.assertive
              : Assertiveness.polite,
        );
      }
    }
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onClosed();
  }

  void _removeNow() {
    _closing = true;
    _timer?.cancel();
    widget.onClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  static String _typeLabel(AppToastType type) => switch (type) {
    AppToastType.success => 'feedback_toast_success'.tr(),
    AppToastType.info => 'feedback_toast_info'.tr(),
    AppToastType.warning => 'feedback_toast_warning'.tr(),
    AppToastType.error => 'feedback_toast_error'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // The toast is an inverse (ink) surface, so status colors come from the
    // opposite palette to keep contrast.
    final inv = p.isDark ? AppPalette.light : AppPalette.dark;
    final (IconData icon, Color iconColor) = switch (widget.type) {
      AppToastType.success => (AppIcons.successFill, inv.accent),
      AppToastType.info => (AppIcons.info, inv.info),
      AppToastType.warning => (AppIcons.warning, inv.owe),
      AppToastType.error => (AppIcons.error, inv.error),
    };
    final top = widget.position == AppToastPosition.top;
    final reduce = AppMotion.reduceMotion(context);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasizedDecelerate,
      reverseCurve: AppMotion.emphasizedAccelerate,
    );

    Widget toast = Material(
      color: p.inverseSurface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.rowRadius),
      elevation: p.isDark ? 0 : AppSpacing.elevationXl,
      shadowColor: p.shadow.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                widget.message,
                style: AppTypography.bodyMedium.copyWith(
                  color: p.onInverseSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.actionLabel != null)
              TextButton(
                onPressed: () {
                  widget.onAction?.call();
                  _close();
                },
                style: TextButton.styleFrom(
                  foregroundColor: inv.accent,
                  minimumSize: const Size(44, 36),
                ),
                child: Text(widget.actionLabel!),
              )
            else
              const SizedBox(width: 6),
          ],
        ),
      ),
    );

    toast = Semantics(
      container: true,
      liveRegion: true,
      label: _typeLabel(widget.type),
      child: toast,
    );

    toast = Dismissible(
      key: const ValueKey('app_toast'),
      direction: top ? DismissDirection.up : DismissDirection.down,
      onDismissed: (_) => _removeNow(),
      child: toast,
    );

    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      child: SafeArea(
        top: top,
        bottom: !top,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedBuilder(
                animation: curved,
                child: toast,
                builder: (context, child) {
                  final t = curved.value;
                  if (reduce) return Opacity(opacity: t, child: child);
                  return Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (top ? -16 : 16) * (1 - t)),
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
