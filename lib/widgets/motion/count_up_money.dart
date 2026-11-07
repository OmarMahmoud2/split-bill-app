import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_motion.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// A [MoneyText] whose amount rolls from the previous value to the new one
/// (600 ms, easeOutCubic) and, by default, up from zero on first build.
/// Formatting, sign, tone and tabular figures are [MoneyText]'s. Under
/// Reduce Motion the final amount shows at once.
class CountUpMoney extends StatefulWidget {
  const CountUpMoney({
    super.key,
    required this.minor,
    required this.currency,
    this.sign = MoneySign.negativeOnly,
    this.tone = MoneyTone.auto,
    this.size = MoneySize.row,
    this.style,
    this.fromZero = true,
    this.showSymbol = true,
    this.textAlign,
    this.semanticsLabel,
  });

  final int minor;
  final String currency;
  final MoneySign sign;
  final MoneyTone tone;
  final MoneySize size;
  final TextStyle? style;

  /// Count up from zero on the first build.
  final bool fromZero;
  final bool showSymbol;
  final TextAlign? textAlign;
  final String? semanticsLabel;

  static const Duration duration = Duration(milliseconds: 600);

  @override
  State<CountUpMoney> createState() => _CountUpMoneyState();
}

class _CountUpMoneyState extends State<CountUpMoney> {
  late int _from = widget.fromZero ? 0 : widget.minor;

  @override
  void didUpdateWidget(CountUpMoney old) {
    super.didUpdateWidget(old);
    if (old.minor != widget.minor) _from = old.minor;
  }

  @override
  Widget build(BuildContext context) {
    Widget money(int minor) => MoneyText(
      minor: minor,
      currency: widget.currency,
      sign: widget.sign,
      tone: widget.tone,
      size: widget.size,
      style: widget.style,
      showSymbol: widget.showSymbol,
      textAlign: widget.textAlign,
      semanticsLabel: widget.semanticsLabel,
    );
    if (AppMotion.reduceMotion(context) || _from == widget.minor) {
      return money(widget.minor);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.minor),
      tween: Tween(begin: _from.toDouble(), end: widget.minor.toDouble()),
      duration: CountUpMoney.duration,
      curve: Curves.easeOutCubic,
      // Tone follows the final amount, so the colour does not flicker while
      // the number crosses zero.
      builder: (context, v, _) => MoneyText(
        minor: v.round(),
        currency: widget.currency,
        sign: widget.sign,
        tone: widget.tone == MoneyTone.auto
            ? (widget.minor > 0
                  ? MoneyTone.owed
                  : widget.minor < 0
                  ? MoneyTone.owe
                  : MoneyTone.neutral)
            : widget.tone,
        size: widget.size,
        style: widget.style,
        showSymbol: widget.showSymbol,
        textAlign: widget.textAlign,
        semanticsLabel: widget.semanticsLabel,
      ),
    );
  }
}
