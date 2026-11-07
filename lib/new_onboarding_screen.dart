import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'package:split_bill_app/widgets/layout/app_scaffold.dart';
import 'package:split_bill_app/services/analytics_service.dart';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/auth_wrapper.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/payment_settings_screen.dart' show countryFlag;
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/currency_selection_sheet.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/motion/motion.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

/// Currency for an ISO region ("EG" -> EGP); euro-area regions give EUR.
/// Null when the region isn't known.
String? currencyForRegion(String? region) {
  final cc = region?.toUpperCase();
  if (cc == null) return null;
  for (final e in currencyHomeCountry.entries) {
    if (e.value == cc) return e.key;
  }
  return sepaEurCountries.contains(cc) ? 'EUR' : null;
}

/// Flag for a currency's home country, or a globe.
String flagForCurrency(String code) {
  final cc = currencyHomeCountry[code];
  return cc == null ? '\u{1F310}' : countryFlag(cc);
}

const _popularCurrencies = ['USD', 'EUR', 'GBP', 'SAR', 'AED', 'EGP', 'INR'];

/// v3 onboarding: scan, split, settle, then the default currency.
/// Persists `onboarding_complete(_v2)` and the chosen currency.
class NewOnboardingScreen extends StatefulWidget {
  const NewOnboardingScreen({super.key, this.debugLocaleTag});

  /// Overrides the device locale used to suggest a currency.
  final String? debugLocaleTag;

  @override
  State<NewOnboardingScreen> createState() => _NewOnboardingScreenState();
}

class _NewOnboardingScreenState extends State<NewOnboardingScreen> {
  static const _pageCount = 4;
  static const _titles = [
    'acct_onb_scan_title',
    'acct_onb_split_title',
    'acct_onb_settle_title',
    'onboarding_title_currency',
  ];
  static const _bodies = [
    'acct_onb_scan_body',
    'acct_onb_split_body',
    'acct_onb_settle_body',
    'onboarding_currency_body',
  ];

  final _controller = PageController();
  int _page = 0;
  bool _loadedDefaults = false;
  bool _completing = false;
  String _currency = 'USD';
  String? _suggested;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedDefaults) return;
    _loadedDefaults = true;
    _currency = context.read<AppSettingsProvider>().currencyCode;
    final region = detectPaymentCountry(
      localeTag:
          widget.debugLocaleTag ??
          ui.PlatformDispatcher.instance.locale.toLanguageTag(),
    );
    _suggested = currencyForRegion(region);
    if (_suggested != null) _currency = _suggested!;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration get _pageDuration =>
      AppMotion.durationFor(context, AppMotion.moneyShort);

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await context.read<AppSettingsProvider>().updateCurrencyCode(_currency);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      await prefs.setBool('onboarding_complete_v2', true);
      AnalyticsService.instance.onboardingComplete();
      if (!mounted) return;
      AppHaptics.success();
      AuthFlow.backToRoot(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _completing = false);
      AppToast.show(
        context,
        message: 'onboarding_save_error'.tr(),
        type: AppToastType.error,
      );
    }
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _complete();
      return;
    }
    AppHaptics.selection();
    _controller.nextPage(duration: _pageDuration, curve: AppMotion.standard);
  }

  void _back() => _controller.previousPage(
    duration: _pageDuration,
    curve: AppMotion.standard,
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyleFor(Theme.of(context).brightness),
      child: AppScaffold(
        body: AdaptiveBody.form(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        24,
                        8,
                        12,
                        0,
                      ),
                      child: Row(
                        children: [
                          if (_page > 0) ...[
                            KeyedSubtree(
                              key: const ValueKey('onboarding-back'),
                              child: V3IconButton.back(
                                context,
                                onPressed: _completing ? null : _back,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          _ProgressDashes(count: _pageCount, current: _page),
                          const Spacer(),
                          TextButton(
                            key: const ValueKey('onboarding-skip'),
                            onPressed: _completing ? null : _complete,
                            style: TextButton.styleFrom(
                              foregroundColor: p.textSecondary,
                            ),
                            child: Text('skip'.tr()),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _pageCount,
                        onPageChanged: (value) => setState(() => _page = value),
                        itemBuilder: (context, index) => _buildPage(index),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        24,
                        12,
                        24,
                        20,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('onboarding-next'),
                          onPressed: _completing ? null : _next,
                          child: _completing
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: p.onInverseSurface,
                                  ),
                                )
                              : Text(
                                  _page == _pageCount - 1
                                      ? 'yx_cur_continue'.tr(
                                          namedArgs: {
                                            'currency':
                                                '${findCurrencyOption(_currency).symbol} $_currency',
                                          },
                                        )
                                      : 'common_continue'.tr(),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _delta(int index) {
    final pos = _controller.hasClients && _controller.position.haveDimensions
        ? (_controller.page ?? _page.toDouble())
        : _page.toDouble();
    return (index - pos).clamp(-1.0, 1.0);
  }

  Widget _buildPage(int index) {
    final p = context.palette;
    final reduce = AppMotion.reduceMotion(context);
    final rtl = Directionality.of(context) == ui.TextDirection.rtl ? -1.0 : 1.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final d = reduce ? 0.0 : _delta(index);
        return SingleChildScrollView(
          key: ValueKey('onboarding-page-$index'),
          padding: const EdgeInsetsDirectional.fromSTEB(24, 32, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Opacity(
                opacity: 1 - d.abs() * 0.6,
                child: Transform.translate(
                  offset: Offset(d * 90 * rtl, 0),
                  child: Transform.scale(
                    scale: 1 - d.abs() * 0.06,
                    child: StaggeredEntrance(
                      child: switch (index) {
                        0 => _ReceiptPreview(),
                        1 => const _SplitPreview(),
                        2 => _settlePreview(),
                        _ => _buildCurrencyStep(),
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Transform.translate(
                offset: Offset(d * 30 * rtl, 0),
                child: Opacity(
                  opacity: 1 - d.abs(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          _titles[index].tr(),
                          style: AppTypography.displaySmall.copyWith(
                            color: p.textPrimary,
                            fontSize: 34,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _bodies[index].tr(),
                        style: AppTypography.bodyLarge.copyWith(
                          color: p.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// A pay-by-link card: who owes what, and a "Pay now" pill. Guests need no app.
  Widget _settlePreview() {
    final p = context.palette;
    Widget row(String name, int minor, {bool paid = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          V3Avatar(name: name, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: AppTypography.titleSmall.copyWith(color: p.textPrimary),
            ),
          ),
          Text(
            formatMoneyMinor(minor, _currency),
            style: AppTypography.amount.copyWith(
              color: paid ? p.accent : p.textPrimary,
              fontSize: 15,
            ),
          ),
          if (paid) ...[
            const SizedBox(width: 6),
            Icon(AppIcons.check, size: 16, color: p.accent),
          ],
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: const _PaidBadge(),
          ),
          row('Sara', 3024, paid: true),
          row('Omar', 3024),
          const SizedBox(height: 10),
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'fr_pay_now'.tr(),
              style: AppTypography.titleSmall.copyWith(color: p.onAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _pick(String code) {
    if (_completing) return;
    AppHaptics.selection();
    setState(() => _currency = code);
  }

  Widget _buildCurrencyStep() {
    final p = context.palette;
    final lang = context.locale.languageCode;
    String nameOf(String code) {
      final fallback = findCurrencyOption(code).name;
      try {
        final n = NumberFormat.currency(locale: lang, name: code).currencyName;
        return n == null || n.isEmpty || n == code ? fallback : n;
      } catch (_) {
        return fallback;
      }
    }

    Widget ring(bool on) => Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? p.accent : Colors.transparent,
        border: Border.all(color: on ? p.accent : p.borderStrong, width: 1.5),
      ),
      child: on ? Icon(AppIcons.check, size: 14, color: p.onAccent) : null,
    );

    final suggested = _suggested;
    final inPopular = _popularCurrencies.contains(_currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suggested != null) ...[
          Text(
            'yx_cur_suggested'.tr(),
            style: AppTypography.labelLarge.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: 8),
          Pressable(
            key: const ValueKey('onboarding-suggested'),
            haptic: true,
            onTap: () => _pick(suggested),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _currency == suggested ? p.accentSoft : p.surface,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(
                  color: _currency == suggested ? p.accent : p.hairline,
                  width: _currency == suggested ? 1.5 : 1,
                ),
                boxShadow: p.softShadow,
              ),
              child: Row(
                children: [
                  Text(
                    flagForCurrency(suggested),
                    style: const TextStyle(fontSize: 34),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${findCurrencyOption(suggested).symbol} $suggested',
                          style: AppTypography.amountLarge.copyWith(
                            color: p.textPrimary,
                            fontSize: 24,
                          ),
                        ),
                        Text(
                          nameOf(suggested),
                          style: AppTypography.bodyMedium.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ring(_currency == suggested),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          'yx_cur_popular'.tr(),
          style: AppTypography.labelLarge.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final code in _popularCurrencies)
              Pressable(
                key: ValueKey('onboarding-pop-$code'),
                onTap: () => _pick(code),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _currency == code ? p.accentSoft : p.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _currency == code ? p.accent : p.hairline,
                      width: _currency == code ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(flagForCurrency(code)),
                      const SizedBox(width: 6),
                      Text(
                        code,
                        style: AppTypography.titleSmall.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Material(
          color: p.surface,
          shape: AppRadii.cardShape(p.hairline),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('onboarding-currency'),
            onTap: _completing
                ? null
                : () => CurrencySelectionSheet.show(
                    context: context,
                    selectedCode: _currency,
                    onSelected: (code) {
                      AppHaptics.selection();
                      setState(() => _currency = code);
                    },
                  ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(AppIcons.search, color: p.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'yx_cur_all'.tr(
                          namedArgs: {
                            'n': '${supportedCurrencyOptions.length}',
                          },
                        ),
                        style: AppTypography.titleSmall.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    if (!inPopular && _currency != suggested)
                      Text(
                        _currency,
                        key: const ValueKey('onboarding-custom-selected'),
                        style: AppTypography.titleSmall.copyWith(
                          color: p.accent,
                        ),
                      ),
                    Icon(AppIcons.chevronRight, color: p.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressDashes extends StatelessWidget {
  const _ProgressDashes({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '${current + 1} / $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppMotion.durationFor(context, AppMotion.medium),
              width: i == current ? 22 : 8,
              height: 8,
              margin: const EdgeInsetsDirectional.only(end: 6),
              decoration: BoxDecoration(
                color: i == current ? p.accent : p.borderStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sample receipt with a teal "read" line, as on the board.
class _ReceiptPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget row(String name, String amount) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: AppTypography.bodyLarge.copyWith(
                color: p.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            amount,
            style: AppTypography.amount.copyWith(
              color: p.textPrimary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'acct_onb_receipt_caption'.tr(namedArgs: {'count': '6'}),
            style: AppTypography.titleSmall.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: 6),
          row('acct_onb_item_burger'.tr(), '14.00'),
          row('acct_onb_item_fries'.tr(), '6.00'),
          row('acct_onb_item_fish'.tr(), '18.50'),
          const SizedBox(height: 6),
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Items with the avatars of who had them.
class _SplitPreview extends StatelessWidget {
  const _SplitPreview();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget row(String name, List<String> people) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: AppTypography.bodyLarge.copyWith(
                color: p.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
          for (var i = 0; i < people.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: AvatarHop(
                duration: Duration(milliseconds: 350 + 80 * i),
                child: V3Avatar(name: people[i], size: 32),
              ),
            ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final n in const ['Ali', 'Sara', 'Omar'])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: V3Avatar(name: n, size: 40),
                ),
            ],
          ),
          const SizedBox(height: 6),
          row('acct_onb_item_burger'.tr(), const ['Ali']),
          row('acct_onb_item_fries'.tr(), const ['Ali', 'Sara', 'Omar']),
          row('acct_onb_item_fish'.tr(), const ['Sara']),
        ],
      ),
    );
  }
}

/// "Paid" pill that pops in once the page is shown.
class _PaidBadge extends StatelessWidget {
  const _PaidBadge();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduce = AppMotion.reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, t, child) =>
          Transform.scale(scale: t.clamp(0.0, 1.3), child: child),
      child: Container(
        key: const ValueKey('onboarding-paid'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: p.accentSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.check, size: 14, color: p.accent),
            const SizedBox(width: 4),
            Text(
              'yx_ob_paid'.tr(),
              style: AppTypography.labelLarge.copyWith(
                color: p.onAccentSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
