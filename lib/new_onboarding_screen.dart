import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'package:split_bill_app/services/analytics_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/auth_wrapper.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/currency_selection_sheet.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

/// v3 onboarding: scan, split, settle, then the default currency.
/// Persists `onboarding_complete(_v2)` and the chosen currency.
class NewOnboardingScreen extends StatefulWidget {
  const NewOnboardingScreen({super.key});

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedDefaults) return;
    _loadedDefaults = true;
    _currency = context.read<AppSettingsProvider>().currencyCode;
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
      child: Scaffold(
        backgroundColor: p.canvas,
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
                                  (_page == _pageCount - 1
                                          ? 'get_started'
                                          : 'common_continue')
                                      .tr(),
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

  Widget _buildPage(int index) {
    final p = context.palette;
    return SingleChildScrollView(
      key: ValueKey('onboarding-page-$index'),
      padding: const EdgeInsetsDirectional.fromSTEB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(
            child: switch (index) {
              0 => _ReceiptPreview(),
              1 => const _SplitPreview(),
              2 => _settlePreview(),
              _ => _buildCurrencyCard(),
            },
          ),
          const SizedBox(height: 36),
          Semantics(
            header: true,
            child: Text(
              _titles[index].tr(),
              style: AppTypography.displaySmall.copyWith(
                color: p.textPrimary,
                fontSize: 34,
                height: 1.1,
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

  Widget _buildCurrencyCard() {
    final p = context.palette;
    final currency = findCurrencyOption(_currency);
    return Material(
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
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: AppRadii.rowRadius,
                ),
                child: FittedBox(
                  child: Text(
                    currency.symbol,
                    style: AppTypography.titleLarge.copyWith(
                      color: p.onAccentSoft,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency.code,
                      style: AppTypography.amountLarge.copyWith(
                        color: p.textPrimary,
                        fontSize: 26,
                      ),
                    ),
                    Text(
                      currency.name,
                      style: AppTypography.bodyMedium.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'choose_currency'.tr(),
                  textAlign: TextAlign.end,
                  style: AppTypography.titleSmall.copyWith(color: p.accent),
                ),
              ),
              Icon(AppIcons.chevronRight, color: p.accent),
            ],
          ),
        ),
      ),
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
              width: i == current ? 24 : 12,
              height: 4,
              margin: const EdgeInsetsDirectional.only(end: 6),
              decoration: BoxDecoration(
                color: i == current ? p.accent : p.borderStrong,
                borderRadius: BorderRadius.circular(2),
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
          row('acct_onb_item_burger'.tr(), const ['Ali']),
          row('acct_onb_item_fries'.tr(), const ['Ali', 'Sara', 'Omar']),
          row('acct_onb_item_fish'.tr(), const ['Sara']),
        ],
      ),
    );
  }
}
