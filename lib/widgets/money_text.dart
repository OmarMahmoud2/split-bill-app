import 'package:flutter/material.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/theme/app_motion.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/theme/app_typography.dart';
import 'package:split_bill_app/utils/money_format.dart';

export 'package:split_bill_app/utils/money_format.dart' show MoneySign;

/// What an amount means to the current user; picks the semantic color.
enum MoneyTone {
  /// Someone owes the user: teal (`palette.owed`).
  owed,

  /// The user owes: amber (`palette.owe`), never red.
  owe,

  /// Informational / settled: ink.
  neutral,

  /// [owed] when positive, [owe] when negative, [neutral] at zero.
  auto,
}

/// Size presets mapping to `AppTypography.amount*` (Plus Jakarta Sans, tabular).
enum MoneySize { small, row, large, hero }

/// An amount of money, formatted per currency (JPY 0, USD 2, KWD 3
/// decimals), with a +/− sign, a semantic color, tabular figures, and an
/// optional count-up when the value changes.
///
/// ```dart
/// MoneyText(minor: 6240, currency: 'USD', sign: MoneySign.always,
///     tone: MoneyTone.auto, size: MoneySize.large, animate: true)
/// // "+$62.40" in teal, counting up from the previous value.
/// MoneyText.money(Money(-1500, 'KWD'))   // "−1.500 د.ك", amber
/// ```
///
/// Color is never the only signal: keep the sign, or put a word next to it
/// ("you owe"), as the spec requires.
class MoneyText extends StatefulWidget {
  const MoneyText({
    super.key,
    required this.minor,
    required this.currency,
    this.sign = MoneySign.negativeOnly,
    this.tone = MoneyTone.auto,
    this.size = MoneySize.row,
    this.style,
    this.animate = false,
    this.animateFromZero = true,
    this.duration = AppMotion.money,
    this.curve = AppMotion.quiet,
    this.showSymbol = true,
    this.locale,
    this.textAlign,
    this.semanticsLabel,
  });

  /// From a domain [Money].
  MoneyText.money(
    Money money, {
    Key? key,
    MoneySign sign = MoneySign.negativeOnly,
    MoneyTone tone = MoneyTone.auto,
    MoneySize size = MoneySize.row,
    TextStyle? style,
    bool animate = false,
    bool animateFromZero = true,
    Duration duration = AppMotion.money,
    Curve curve = AppMotion.quiet,
    bool showSymbol = true,
    String? locale,
    TextAlign? textAlign,
    String? semanticsLabel,
  }) : this(
         key: key,
         minor: money.minor,
         currency: money.currency,
         sign: sign,
         tone: tone,
         size: size,
         style: style,
         animate: animate,
         animateFromZero: animateFromZero,
         duration: duration,
         curve: curve,
         showSymbol: showSymbol,
         locale: locale,
         textAlign: textAlign,
         semanticsLabel: semanticsLabel,
       );

  /// Amount in minor units (cents, yen, fils).
  final int minor;
  final String currency;
  final MoneySign sign;
  final MoneyTone tone;
  final MoneySize size;

  /// Merged over the size preset (e.g. to change the font size).
  final TextStyle? style;

  /// Count up from the previous value (and from zero on first build when
  /// [animateFromZero]). Skipped under Reduce Motion.
  final bool animate;
  final bool animateFromZero;
  final Duration duration;
  final Curve curve;
  final bool showSymbol;
  final String? locale;
  final TextAlign? textAlign;

  /// Screen reader label; defaults to the formatted amount.
  final String? semanticsLabel;

  /// The color for [tone] and [minor] in [p].
  static Color colorFor(AppPalette p, MoneyTone tone, int minor) {
    switch (tone) {
      case MoneyTone.owed:
        return p.owed;
      case MoneyTone.owe:
        return p.owe;
      case MoneyTone.neutral:
        return p.neutralAmount;
      case MoneyTone.auto:
        if (minor > 0) return p.owed;
        if (minor < 0) return p.owe;
        return p.neutralAmount;
    }
  }

  /// How big the currency symbol and sign are next to the digits: small
  /// beside big amounts, readable in rows.
  static double symbolScale(MoneySize size) => switch (size) {
    MoneySize.hero || MoneySize.large => 0.62,
    MoneySize.row => 0.8,
    MoneySize.small => 1,
  };

  static TextStyle styleFor(MoneySize size) => switch (size) {
    MoneySize.small => AppTypography.amountSmall,
    MoneySize.row => AppTypography.amount,
    MoneySize.large => AppTypography.amountLarge,
    MoneySize.hero => AppTypography.amountHero,
  };

  @override
  State<MoneyText> createState() => _MoneyTextState();
}

class _MoneyTextState extends State<MoneyText> {
  late int _from;

  @override
  void initState() {
    super.initState();
    _from = widget.animate && widget.animateFromZero ? 0 : widget.minor;
  }

  @override
  void didUpdateWidget(MoneyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minor != widget.minor) _from = oldWidget.minor;
  }

  String _format(int minor) => formatMoneyMinor(
    minor,
    widget.currency,
    sign: widget.sign,
    showSymbol: widget.showSymbol,
    locale: widget.locale,
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final finalText = _format(widget.minor);
    final color = MoneyText.colorFor(p, widget.tone, widget.minor);
    final style = MoneyText.styleFor(
      widget.size,
    ).copyWith(color: color).merge(widget.style);

    final scale = MoneyText.symbolScale(widget.size);
    final baseSize = style.fontSize ?? 16;

    // Sign and symbol are their own spans, smaller than the digits and on
    // the same baseline. An LTR paragraph so "+$12.00" never reorders inside
    // RTL rows. (Bidi isolate marks measured one glyph short in RTL and
    // clipped "E£0.00".)
    InlineSpan spans(int minor) {
      final full = _format(minor);
      if (scale == 1 || !widget.showSymbol) return TextSpan(text: full);
      final number = formatMoneyMinor(
        minor.abs(),
        widget.currency,
        sign: MoneySign.none,
        showSymbol: false,
        locale: widget.locale,
      );
      final at = full.indexOf(number);
      if (at < 0) return TextSpan(text: full);
      final small = TextStyle(fontSize: baseSize * scale);
      return TextSpan(
        children: [
          if (at > 0) TextSpan(text: full.substring(0, at), style: small),
          TextSpan(text: number),
          if (at + number.length < full.length)
            TextSpan(text: full.substring(at + number.length), style: small),
        ],
      );
    }

    Widget text(int minor) => Text.rich(
      TextSpan(children: [spans(minor)]),
      style: style,
      textDirection: TextDirection.ltr,
      textAlign: widget.textAlign,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      semanticsLabel: widget.semanticsLabel ?? finalText,
    );

    final shouldAnimate =
        widget.animate &&
        _from != widget.minor &&
        !AppMotion.reduceMotion(context);
    if (!shouldAnimate) return text(widget.minor);

    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.minor),
      tween: Tween(begin: _from.toDouble(), end: widget.minor.toDouble()),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, v, _) => text(v.round()),
    );
  }
}
