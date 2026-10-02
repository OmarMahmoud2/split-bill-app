import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/auth_wrapper.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/services/user_preferences_service.dart';

class NewOnboardingScreen extends StatefulWidget {
  const NewOnboardingScreen({super.key});

  @override
  State<NewOnboardingScreen> createState() => _NewOnboardingScreenState();
}

class _NewOnboardingScreenState extends State<NewOnboardingScreen>
    with TickerProviderStateMixin {
  static const _popularCurrencyCodes = <String>[
    'USD',
    'EUR',
    'GBP',
    'EGP',
    'SAR',
    'AED',
    'INR',
    'IDR',
    'PHP',
    'BRL',
    'MXN',
    'ZAR',
  ];

  final _pageController = PageController();
  final _customCurrencyController = TextEditingController();
  final _paymentNameController = TextEditingController();
  final _paymentDetailController = TextEditingController();

  late final AnimationController _gradientController;
  late final AnimationController _floatingController;

  int _currentPage = 0;
  bool _loadedProviderDefaults = false;
  bool _isCompleting = false;
  String _selectedCurrencyCode = UserPreferencesService.defaultCurrencyCode;
  final List<Map<String, String>> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedProviderDefaults) return;
    _loadedProviderDefaults = true;

    final settings = context.read<AppSettingsProvider>();
    _selectedCurrencyCode =
        sanitizeCurrencyCode(settings.currencyCode) ??
        UserPreferencesService.defaultCurrencyCode;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customCurrencyController.dispose();
    _paymentNameController.dispose();
    _paymentDetailController.dispose();
    _gradientController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  List<_OnboardingPage> get _pages => [
    _OnboardingPage(
      title: 'onboarding_title_scan_split'.tr(),
      description: 'onboarding_desc_scan_split'.tr(),
      icon: Icons.receipt_long_rounded,
      colors: const [Color(0xFF1677FF), Color(0xFF7C3AED)],
      body: _buildIntroPage,
    ),
    _OnboardingPage(
      title: 'onboarding_title_currency'.tr(),
      description: 'onboarding_desc_currency'.tr(),
      icon: Icons.payments_rounded,
      colors: const [Color(0xFF0F9B8E), Color(0xFF2563EB)],
      body: _buildCurrencyPage,
    ),
    _OnboardingPage(
      title: 'onboarding_title_payments'.tr(),
      description: 'onboarding_desc_payments'.tr(),
      icon: Icons.account_balance_wallet_rounded,
      colors: const [Color(0xFFF97316), Color(0xFFDB2777)],
      body: _buildPaymentMethodsPage,
    ),
    _OnboardingPage(
      title: 'onboarding_title_no_collection'.tr(),
      description: 'onboarding_desc_no_collection'.tr(),
      icon: Icons.verified_user_rounded,
      colors: const [Color(0xFF475569), Color(0xFF0891B2)],
      body: _buildTrustPage,
    ),
    _OnboardingPage(
      title: 'onboarding_title_ready'.tr(),
      description: 'onboarding_desc_ready'.tr(),
      icon: Icons.check_circle_rounded,
      colors: const [Color(0xFF16A34A), Color(0xFF0EA5E9)],
      body: _buildReadyPage,
    ),
  ];

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;

    setState(() => _isCompleting = true);

    final settings = context.read<AppSettingsProvider>();
    final prefs = await SharedPreferences.getInstance();
    final selectedCurrency =
        sanitizeCurrencyCode(_selectedCurrencyCode) ??
        UserPreferencesService.defaultCurrencyCode;

    await prefs.setBool('onboarding_complete', true);
    await prefs.setBool('onboarding_complete_v2', true);
    await prefs.setString('currencyCode', selectedCurrency);

    if (_paymentMethods.isNotEmpty) {
      await prefs.setString(
        UserPreferencesService.pendingPaymentMethodsKey,
        jsonEncode(_paymentMethods),
      );
    } else {
      await prefs.remove(UserPreferencesService.pendingPaymentMethodsKey);
    }

    await settings.updateCurrencyCode(selectedCurrency);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthWrapper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 420),
      ),
      (route) => false,
    );
  }

  void _goNextOrComplete() {
    if (_currentPage == _pages.length - 1) {
      _completeOnboarding();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  void _selectCurrency(String code) {
    final normalized = sanitizeCurrencyCode(code);
    if (normalized == null) return;
    setState(() {
      _selectedCurrencyCode = normalized;
      _customCurrencyController.clear();
    });
  }

  void _saveCustomCurrency() {
    final normalized = sanitizeCurrencyCode(_customCurrencyController.text);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('onboarding_custom_currency_error'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _selectedCurrencyCode = normalized);
    FocusScope.of(context).unfocus();
  }

  void _addPaymentMethod() {
    final name = _paymentNameController.text.trim();
    final value = _paymentDetailController.text.trim();

    if (name.isEmpty || value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_complete_all_required_fields'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _paymentMethods.add({'name': name, 'value': value});
      _paymentNameController.clear();
      _paymentDetailController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = _pages;
    final currentPage = pages[_currentPage];
    final colors = currentPage.colors;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_gradientController, _floatingController]),
        builder: (context, child) {
          final shift = _gradientController.value;
          final lift = (_floatingController.value - 0.5) * 16;

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(colors.first, colors.last, shift)!,
                  Color.lerp(colors.last, colors.first, shift)!,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        _ProgressDots(
                          count: pages.length,
                          activeIndex: _currentPage,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isCompleting ? null : _completeOnboarding,
                          child: Text(
                            'skip'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) =>
                          setState(() => _currentPage = index),
                      itemCount: pages.length,
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                16,
                                24,
                                24,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - 40,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: Offset(0, lift),
                                      child: _HeroIcon(
                                        icon: page.icon,
                                        colors: page.colors,
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    Text(
                                      page.title,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            height: 1.08,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      page.description,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.86,
                                            ),
                                            height: 1.45,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 26),
                                    page.body(context),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _isCompleting ? null : _goNextOrComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: colors.first,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isCompleting
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: colors.first,
                                ),
                              )
                            : Text(
                                _currentPage == pages.length - 1
                                    ? 'get_started_rocket'.tr()
                                    : 'next'.tr(),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntroPage(BuildContext context) {
    return _GlassPanel(
      child: Column(
        children: [
          _FeatureRow(
            icon: Icons.camera_alt_rounded,
            title: 'scan_receipts_ninstantly'.tr(),
            subtitle: 'onboarding_scan_description'.tr(),
          ),
          const SizedBox(height: 14),
          _FeatureRow(
            icon: Icons.groups_rounded,
            title: 'split_bills_nfairly'.tr(),
            subtitle: 'onboarding_split_description'.tr(),
          ),
          const SizedBox(height: 14),
          _FeatureRow(
            icon: Icons.notifications_active_rounded,
            title: 'stay_updated_nalways'.tr(),
            subtitle: 'onboarding_notifications_description'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyPage(BuildContext context) {
    final theme = Theme.of(context);
    final selected = findCurrencyOption(_selectedCurrencyCode);

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE0F2FE),
                  foregroundColor: const Color(0xFF0369A1),
                  child: Text(
                    selected.symbol,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.code,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${selected.name} • ${selected.region}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black.withValues(alpha: 0.56),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF0F9B8E),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'onboarding_popular_currencies'.tr(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _popularCurrencyCodes.map((code) {
              final option = findCurrencyOption(code);
              final isSelected = _selectedCurrencyCode == option.code;
              return ChoiceChip(
                selected: isSelected,
                label: Text('${option.symbol} ${option.code}'),
                onSelected: (_) => _selectCurrency(option.code),
                selectedColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: isSelected ? 1 : 0.24),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          _TextInputPanel(
            controller: _customCurrencyController,
            label: 'onboarding_custom_currency_label'.tr(),
            hint: 'onboarding_custom_currency_hint'.tr(),
            icon: Icons.edit_rounded,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
              LengthLimitingTextInputFormatter(6),
            ],
            action: IconButton(
              tooltip: 'save_changes'.tr(),
              onPressed: _saveCustomCurrency,
              icon: const Icon(Icons.check_circle_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsPage(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TextInputPanel(
            controller: _paymentNameController,
            label: 'onboarding_payment_name_label'.tr(),
            hint: 'onboarding_payment_name_hint'.tr(),
            icon: Icons.wallet_rounded,
          ),
          const SizedBox(height: 12),
          _TextInputPanel(
            controller: _paymentDetailController,
            label: 'onboarding_payment_detail_label'.tr(),
            hint: 'onboarding_payment_detail_hint'.tr(),
            icon: Icons.alternate_email_rounded,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addPaymentMethod(),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _addPaymentMethod,
            icon: const Icon(Icons.add_circle_rounded),
            label: Text('onboarding_add_payment'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _paymentMethods.isEmpty
                ? 'onboarding_no_payment_methods'.tr()
                : 'onboarding_added_payment_methods'.tr(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ..._paymentMethods.asMap().entries.map((entry) {
            final method = entry.value;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEDD5),
                    foregroundColor: Color(0xFFEA580C),
                    child: Icon(Icons.payments_rounded),
                  ),
                  title: Text(
                    method['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(method['value'] ?? ''),
                  trailing: IconButton(
                    onPressed: () =>
                        setState(() => _paymentMethods.removeAt(entry.key)),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTrustPage(BuildContext context) {
    return _GlassPanel(
      child: Column(
        children: [
          _FeatureRow(
            icon: Icons.money_off_csred_rounded,
            title: 'onboarding_no_collection_point_1'.tr(),
            subtitle: 'onboarding_no_collection_point_1_desc'.tr(),
          ),
          const SizedBox(height: 14),
          _FeatureRow(
            icon: Icons.privacy_tip_rounded,
            title: 'onboarding_no_collection_point_2'.tr(),
            subtitle: 'onboarding_no_collection_point_2_desc'.tr(),
          ),
          const SizedBox(height: 14),
          _FeatureRow(
            icon: Icons.share_rounded,
            title: 'onboarding_no_collection_point_3'.tr(),
            subtitle: 'onboarding_no_collection_point_3_desc'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyPage(BuildContext context) {
    final selected = findCurrencyOption(_selectedCurrencyCode);

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryTile(
            icon: Icons.payments_rounded,
            title: 'default_currency'.tr(),
            value: '${selected.code} • ${selected.name}',
          ),
          const SizedBox(height: 12),
          _SummaryTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'payment_methods'.tr(),
            value: _paymentMethods.isEmpty
                ? 'onboarding_no_payment_methods'.tr()
                : '${_paymentMethods.length}',
          ),
          const SizedBox(height: 12),
          _SummaryTile(
            icon: Icons.security_rounded,
            title: 'onboarding_title_no_collection'.tr(),
            value: 'onboarding_no_collection_point_1'.tr(),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
    required this.body,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final Widget Function(BuildContext context) body;
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: active ? 28 : 8,
          height: 8,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon, required this.colors});

  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) =>
              LinearGradient(colors: colors).createShader(bounds),
          child: Icon(icon, size: 58, color: Colors.white),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      child: child,
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextInputPanel extends StatelessWidget {
  const _TextInputPanel({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.action,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Widget? action;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: action,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
