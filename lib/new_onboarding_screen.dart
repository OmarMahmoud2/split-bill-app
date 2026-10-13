import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/auth_wrapper.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/widgets/currency_selection_sheet.dart';

class NewOnboardingScreen extends StatefulWidget {
  const NewOnboardingScreen({super.key});

  @override
  State<NewOnboardingScreen> createState() => _NewOnboardingScreenState();
}

class _NewOnboardingScreenState extends State<NewOnboardingScreen> {
  static const _ink = Color(0xFF172C35);
  static const _accent = Color(0xFF008A86);
  static const _backgrounds = [
    Color(0xFFF4FAF8),
    Color(0xFFF2F6FF),
    Color(0xFFF7F3FC),
    Color(0xFFFFF8ED),
  ];
  static const _titles = [
    'onboarding_title_scan_split',
    'onboarding_scan_title',
    'onboarding_voice_title',
    'onboarding_title_currency',
  ];
  static const _descriptions = [
    'onboarding_desc_scan_split',
    'onboarding_scan_body',
    'onboarding_voice_body',
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

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await context.read<AppSettingsProvider>().updateCurrencyCode(_currency);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      await prefs.setBool('onboarding_complete_v2', true);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const AuthWrapper(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 250),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _completing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('onboarding_save_error'.tr())));
    }
  }

  void _next() {
    if (_page == 3) {
      _complete();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: AnimatedContainer(
          duration: Duration(milliseconds: reducedMotion ? 0 : 320),
          color: _backgrounds[_page],
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      if (_page > 0)
                        TextButton(
                          key: const ValueKey('onboarding-back'),
                          onPressed: _completing
                              ? null
                              : () => _controller.previousPage(
                                  duration: Duration(
                                    milliseconds: reducedMotion ? 1 : 320,
                                  ),
                                  curve: Curves.easeOutCubic,
                                ),
                          child: Text('back'.tr()),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 40,
                            height: 40,
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        key: const ValueKey('onboarding-skip'),
                        onPressed: _completing ? null : _complete,
                        child: Text('skip'.tr()),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
                  child: Row(
                    children: List.generate(
                      4,
                      (i) => Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i <= _page
                                ? _accent
                                : _ink.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: 4,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (context, index) => _buildPage(index),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('onboarding-next'),
                          onPressed: _completing ? null : _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _completing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  (_page == 3 ? 'get_started' : 'next').tr(),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(int index) => LayoutBuilder(
    builder: (context, constraints) {
      final heroHeight = (constraints.maxHeight * 0.45).clamp(180.0, 340.0);
      return SingleChildScrollView(
        key: ValueKey('onboarding-page-$index'),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 504),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titles[index].tr(),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 34,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _descriptions[index].tr(),
                  style: const TextStyle(
                    color: Color(0xFF53676E),
                    fontSize: 17,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                if (index == 0 || index == 1)
                  SizedBox(
                    height: heroHeight,
                    width: double.infinity,
                    child: Image.asset(
                      index == 0
                          ? 'assets/onboarding/onboarding_split_bill_1767296158711-removebg-preview.png'
                          : 'assets/onboarding/onboarding_scan_receipt_1767296144198-removebg-preview.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                if (index == 2) _buildVoiceIllustration(heroHeight),
                if (index == 3) _buildCurrencyCard(),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 20,
                      color: _accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        [
                          'onboarding_split_hint',
                          'onboarding_scan_hint',
                          'onboarding_voice_hint',
                          'onboarding_currency_hint',
                        ][index].tr(),
                        style: const TextStyle(
                          color: Color(0xFF53676E),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildVoiceIllustration(double height) => Container(
    constraints: BoxConstraints(minHeight: height),
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(32),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: Color(0xFFF0E7FC),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mic_rounded,
            size: 42,
            color: Color(0xFF8056B1),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            23,
            (i) => Container(
              width: 4,
              height: [12.0, 24.0, 40.0, 20.0, 32.0][i % 5],
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF8056B1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'voice_try_example'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _buildCurrencyCard() {
    final currency = findCurrencyOption(_currency);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        key: const ValueKey('onboarding-currency'),
        borderRadius: BorderRadius.circular(28),
        onTap: _completing
            ? null
            : () => CurrencySelectionSheet.show(
                context: context,
                selectedCode: _currency,
                onSelected: (code) => setState(() => _currency = code),
              ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2D8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FittedBox(
                  child: Text(
                    currency.symbol,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                currency.code,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                currency.name,
                style: const TextStyle(color: Color(0xFF53676E), fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'choose_currency'.tr(),
                      style: const TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: _accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
