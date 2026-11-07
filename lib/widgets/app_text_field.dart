import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/motion/motion.dart';

/// Evens text field: label above, 52 px tall, radius 14, hairline border;
/// focus = 2 px mint border plus a 4 px mint ring at 12% (the theme cannot
/// draw the ring). A non-null [errorText] shows below the field in the error
/// colour, shakes once and fires the warning haptic when it first appears.
///
/// [money] switches to big tabular Plus Jakarta numbers.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.enabled = true,
    this.money = false,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool enabled;
  final bool money;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _shake = ShakeController();
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(AppTextField old) {
    super.didUpdateWidget(old);
    if (widget.errorText != null && old.errorText == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _shake.shake();
      });
    }
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_rebuild);
    _ownFocus?.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasError = widget.errorText != null;
    final focused = _focus.hasFocus;
    final borderColor = hasError
        ? p.error
        : focused
        ? p.accent
        : p.border;
    final textStyle = widget.money
        ? AppTypography.amount.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: p.textPrimary,
            fontFeatures: AppTypography.tabularFigures,
          )
        : AppTypography.bodyLarge.copyWith(color: p.textPrimary);
    final field = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 52,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: widget.enabled ? p.surface : p.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: focused || hasError ? 2 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: (hasError ? p.error : p.accent).withValues(
                    alpha: 0.12,
                  ),
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          if (widget.prefix != null) ...[
            widget.prefix!,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              inputFormatters: widget.inputFormatters,
              textCapitalization: widget.textCapitalization,
              maxLength: widget.maxLength,
              textAlign: widget.textAlign,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: textStyle,
              cursorColor: p.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                // The theme's contentPadding would be added on top of the
                // container's inset.
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                counterText: '',
                hintText: widget.hint,
                hintStyle: textStyle.copyWith(
                  color: p.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (widget.suffix != null) ...[
            const SizedBox(width: 8),
            widget.suffix!,
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.labelMedium.copyWith(
              color: p.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        ShakeOnError(controller: _shake, child: field),
        if (hasError || widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText ?? widget.helperText!,
            style: AppTypography.bodySmall.copyWith(
              color: hasError ? p.error : p.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
