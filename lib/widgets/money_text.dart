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

/// Size presets mapping to `AppTypography.amount*` (Inter Tight, tabular).
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

    Widget text(String value) => Text(
      // Isolate as LTR so "+$12.00" never reorders inside RTL rows.
      '\u2066$value\u2069',
      style: style,
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
    if (!shouldAnimate) return text(finalText);

    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.minor),
      tween: Tween(begin: _from.toDouble(), end: widget.minor.toDouble()),
      duration: widget.duration,
      curve: AppMotion.quiet,
      builder: (context, v, _) => text(_format(v.round())),
    );
  }
}
