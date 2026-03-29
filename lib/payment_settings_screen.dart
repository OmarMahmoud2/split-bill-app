import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/widgets/custom_app_header.dart';
import 'package:split_bill_app/widgets/empty_state_widget.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:split_bill_app/widgets/searchable_selection_sheet.dart';
import 'package:split_bill_app/widgets/success_state_widget.dart';
import 'package:easy_localization/easy_localization.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSuccess = false;
  List<Map<String, dynamic>> _methods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (doc.exists && doc.data() is Map<String, dynamic>) {
        final data = doc.data() as Map<String, dynamic>;

        if (data['customPaymentMethods'] != null) {
          _methods = List<Map<String, dynamic>>.from(data['customPaymentMethods']);
        } else if (data['paymentMethods'] != null) {
          final oldMethods = data['paymentMethods'] as Map<String, dynamic>;
          oldMethods.forEach((key, value) {
            if (value.toString().trim().isNotEmpty) {
              _methods.add({'name': key.toUpperCase(), 'value': value.toString()});
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading payment methods: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (user == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'customPaymentMethods': _methods});

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSuccess = true;
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'error_saving_payment_methods'.tr(
              namedArgs: {'error': e.toString()},
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  PaymentMethodPreset _presetForName(String name) {
    for (final preset in _paymentMethodPresets) {
      if (preset.name.toLowerCase() == name.toLowerCase()) {
        return preset;
      }
    }
    return otherPreset;
  }

  Future<PaymentMethodPreset?> _pickPreset(PaymentMethodPreset selectedPreset) {
    return showModalBottomSheet<PaymentMethodPreset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SearchableSelectionSheet<PaymentMethodPreset>(
          title: 'choose_payment_method'.tr(),
          searchHint: 'search_payment_methods'.tr(),
          items: _paymentMethodPresets
              .map(
                (preset) => SearchableSheetItem<PaymentMethodPreset>(
                  value: preset,
                  title: preset.nameKey.tr(),
                  subtitle: preset.subtitleKey.tr(),
                  searchTerms: [
                    preset.name,
                    preset.nameKey.tr(),
                    preset.subtitleKey.tr(),
                    ...preset.searchTerms,
                  ],
                  leading: _MethodBadge(
                    icon: preset.icon,
                    color: preset.color,
                  ),
                ),
              )
              .toList(),
          isSelected: (preset) => preset.name == selectedPreset.name,
          onSelected: (preset) => Navigator.pop(context, preset),
        );
      },
    );
  }

  Future<void> _showMethodEditor({int? index}) async {
    final existingMethod = index != null ? _methods[index] : null;
    final initialName = existingMethod?['name']?.toString() ?? '';
    final initialValue = existingMethod?['value']?.toString() ?? '';

    PaymentMethodPreset selectedPreset = initialName.isEmpty
        ? instapayPreset
        : _presetForName(initialName);

    final nameController = TextEditingController(
      text: selectedPreset == otherPreset ? initialName : '',
    );
    final valueController = TextEditingController(text: initialValue);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final isEditing = index != null;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          isEditing
                              ? 'edit_payment_method'.tr()
                              : 'add_payment_method'.tr(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('choose_how_friends_can_pay_you_then_add_the_exact_handle_phone_number_link_or_account_detail_they_need',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            height: 1.45,
                          ),
                        ).tr(),
                        const SizedBox(height: 18),
                        Text('method_type',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.black54,
                          ),
                        ).tr(),
                        const SizedBox(height: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final preset = await _pickPreset(selectedPreset);
                              if (preset == null) return;
                              setModalState(() {
                                selectedPreset = preset;
                                if (preset != otherPreset) {
                                  nameController.clear();
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(22),
                            child: Ink(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFF),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFFE6EBF5)),
                              ),
                              child: Row(
                                children: [
                                  _MethodBadge(
                                    icon: selectedPreset.icon,
                                    color: selectedPreset.color,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedPreset.nameKey.tr(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          selectedPreset.subtitleKey.tr(),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.expand_more_rounded),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (selectedPreset == otherPreset) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'custom_method_name'.tr(),
                              hintText: 'e_g_bankak_or_stripe_payment_link'.tr(),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: valueController,
                          decoration: InputDecoration(
                            labelText: selectedPreset.valueLabelKey.tr(),
                            hintText: selectedPreset.placeholderKey.tr(),
                            helperText: selectedPreset.helperTextKey.tr(),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            if (isEditing)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() => _methods.removeAt(index));
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  label: Text('common_remove').tr(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade600,
                                    side: BorderSide(color: Colors.red.shade100),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                              ),
                            if (isEditing) const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final finalName = selectedPreset == otherPreset
                                      ? nameController.text.trim()
                                      : selectedPreset.name;
                                  final finalValue = valueController.text.trim();

                                  if (finalName.isEmpty || finalValue.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('please_complete_all_required_fields').tr(),
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() {
                                    if (index == null) {
                                      _methods.add({
                                        'name': finalName,
                                        'value': finalValue,
                                      });
                                    } else {
                                      _methods[index] = {
                                        'name': finalName,
                                        'value': finalValue,
                                      };
                                    }
                                  });
                                  Navigator.pop(context);
                                },
                                icon: Icon(
                                  isEditing
                                      ? Icons.save_rounded
                                      : Icons.add_circle_outline_rounded,
                                ),
                                label: Text(
                                  isEditing
                                      ? 'save_changes'.tr()
                                      : 'add_method'.tr(),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blueAccent,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text('how_payment_methods_work',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ).tr(),
              const SizedBox(height: 10),
              Text('add_the_ways_you_prefer_to_receive_money_these_details_appear_when_a_bill_is_shared_so_people_can_pay_you_faster_without_asking_for_your_handle_again',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.45),
              ).tr(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('got_it_2').tr(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: CustomAppHeader(
        title: 'payment_methods'.tr(),
        infoMessage: 'payment_methods_info_message'.tr(),
      ),
      body: _isSaving
          ? LoadingStateWidget(message: 'saving_payment_methods'.tr())
          : _isSuccess
              ? SuccessStateWidget(
                  message: 'payment_methods_updated'.tr(),
                  onAction: () => Navigator.pop(context),
                )
              : _isLoading
                  ? LoadingStateWidget(message: 'loading_your_methods'.tr())
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'payment_methods_saved_count'.tr(
                                          namedArgs: {
                                            'count': _methods.length.toString(),
                                          },
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('keep_the_links_and_usernames_people_actually_use_most',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ).tr(),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _showInfo,
                                  icon: const Icon(Icons.info_outline_rounded),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _methods.isEmpty
                              ? EmptyStateWidget(
                                  title: 'add_your_payment_methods'.tr(),
                                  message: 'start_with_the_apps_or_wallets_you_actually_want_friends_to_use_when_they_pay_you_back'.tr(),
                                  actionLabel: 'add_method'.tr(),
                                  onAction: () => _showMethodEditor(),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                                  itemCount: _methods.length,
                                  itemBuilder: (context, index) =>
                                      _buildMethodTile(_methods[index], index),
                                ),
                        ),
                      ],
                    ),
      floatingActionButton: (!_isLoading && !_isSaving && !_isSuccess)
          ? Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text('scan_save_changes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ).tr(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    onPressed: () => _showMethodEditor(),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMethodTile(Map<String, dynamic> method, int index) {
    final preset = _presetForName(method['name'].toString());
    final accent = preset == otherPreset ? Colors.blueGrey : preset.color;
    final icon = preset == otherPreset ? Icons.tune_rounded : preset.icon;
    final displayName =
        preset == otherPreset && method['name'].toString() != otherPreset.name
        ? method['name'].toString()
        : preset.nameKey.tr();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showMethodEditor(index: index),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _MethodBadge(icon: icon, color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        method['value'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded, size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text('common_edit',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ).tr(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class PaymentMethodPreset {
  const PaymentMethodPreset({
    required this.name,
    required this.nameKey,
    required this.subtitleKey,
    required this.icon,
    required this.color,
    required this.valueLabelKey,
    required this.placeholderKey,
    required this.helperTextKey,
    this.searchTerms = const [],
  });

  final String name;
  final String nameKey;
  final String subtitleKey;
  final IconData icon;
  final Color color;
  final String valueLabelKey;
  final String placeholderKey;
  final String helperTextKey;
  final List<String> searchTerms;
}

final instapayPreset = PaymentMethodPreset(
  name: 'InstaPay',
  nameKey: 'payment_method_instapay',
  subtitleKey: 'egypt_instant_account_to_account_payments',
  icon: Icons.flash_on_rounded,
  color: Color(0xFF5E5CE6),
  valueLabelKey: 'payment_method_instapay_value_label',
  placeholderKey: 'payment_method_instapay_placeholder',
  helperTextKey: 'use_the_exact_handle_or_link_you_want_shared',
  searchTerms: ['egypt', 'bank', 'instapay'],
);

final otherPreset = PaymentMethodPreset(
  name: 'Other',
  nameKey: 'payment_method_other',
  subtitleKey: 'use_a_custom_payment_method_name',
  icon: Icons.tune_rounded,
  color: Color(0xFF607D8B),
  valueLabelKey: 'payment_method_other_value_label',
  placeholderKey: 'payment_method_other_placeholder',
  helperTextKey: 'best_for_methods_not_listed_here',
);

final _paymentMethodPresets = <PaymentMethodPreset>[
  instapayPreset,
  PaymentMethodPreset(
    name: 'Vodafone Cash',
    nameKey: 'payment_method_vodafone_cash',
    subtitleKey: 'egypt_mobile_wallet_and_payment_card_details',
    icon: Icons.phone_android_rounded,
    color: Color(0xFFE53935),
    valueLabelKey: 'payment_method_vodafone_cash_value_label',
    placeholderKey: 'payment_method_vodafone_cash_placeholder',
    helperTextKey: 'great_when_you_want_people_to_pay_via_mobile_wallet',
    searchTerms: ['egypt', 'wallet', 'vodafone'],
  ),
  PaymentMethodPreset(
    name: 'PayPal',
    nameKey: 'payment_method_paypal',
    subtitleKey: 'global_wallet_requests_and_payment_links',
    icon: Icons.paypal_rounded,
    color: Color(0xFF0070BA),
    valueLabelKey: 'payment_method_paypal_value_label',
    placeholderKey: 'payment_method_paypal_placeholder',
    helperTextKey: 'use_your_paypal_me_or_the_address_people_pay',
    searchTerms: ['wallet', 'global', 'paypal'],
  ),
  PaymentMethodPreset(
    name: 'Venmo',
    nameKey: 'payment_method_venmo',
    subtitleKey: 'fast_social_payments_in_the_us',
    icon: Icons.send_rounded,
    color: Color(0xFF008CFF),
    valueLabelKey: 'payment_method_venmo_value_label',
    placeholderKey: 'payment_method_venmo_placeholder',
    helperTextKey: 'use_the_handle_friends_search_for_in_venmo',
    searchTerms: ['usa', 'social', 'venmo'],
  ),
  PaymentMethodPreset(
    name: 'Cash App',
    nameKey: 'payment_method_cash_app',
    subtitleKey: 'us_payments_with_cashtag_support',
    icon: Icons.attach_money_rounded,
    color: Color(0xFF00D632),
    valueLabelKey: 'payment_method_cash_app_value_label',
    placeholderKey: 'payment_method_cash_app_placeholder',
    helperTextKey: 'share_your_cashtag_exactly_as_it_appears',
    searchTerms: ['usa', 'cashtag', 'cashapp'],
  ),
  PaymentMethodPreset(
    name: 'Zelle',
    nameKey: 'payment_method_zelle',
    subtitleKey: 'us_bank_linked_transfers',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF6D1ED4),
    valueLabelKey: 'payment_method_zelle_value_label',
    placeholderKey: 'payment_method_zelle_placeholder',
    helperTextKey: 'use_the_phone_or_email_your_bank_uses_for_zelle',
    searchTerms: ['usa', 'bank', 'zelle'],
  ),
  PaymentMethodPreset(
    name: 'Apple Cash',
    nameKey: 'payment_method_apple_cash',
    subtitleKey: 'iphone_wallet_payments_and_requests',
    icon: Icons.apple_rounded,
    color: Color(0xFF111111),
    valueLabelKey: 'payment_method_apple_cash_value_label',
    placeholderKey: 'payment_method_apple_cash_placeholder',
    helperTextKey: 'share_the_contact_people_should_use_to_find_you',
    searchTerms: ['apple', 'wallet', 'ios'],
  ),
  PaymentMethodPreset(
    name: 'Revolut',
    nameKey: 'payment_method_revolut',
    subtitleKey: 'international_transfers_and_payment_links',
    icon: Icons.currency_exchange_rounded,
    color: Color(0xFF0055FF),
    valueLabelKey: 'payment_method_revolut_value_label',
    placeholderKey: 'payment_method_revolut_placeholder',
    helperTextKey: 'use_your_revtag_or_a_payment_link',
    searchTerms: ['revolut', 'revtag', 'transfer'],
  ),
  PaymentMethodPreset(
    name: 'Wise',
    nameKey: 'payment_method_wise',
    subtitleKey: 'international_transfer_details_and_links',
    icon: Icons.public_rounded,
    color: Color(0xFF00B9FF),
    valueLabelKey: 'payment_method_wise_value_label',
    placeholderKey: 'payment_method_wise_placeholder',
    helperTextKey: 'good_for_cross_border_settlements',
    searchTerms: ['wise', 'global', 'international'],
  ),
  PaymentMethodPreset(
    name: 'M-Pesa',
    nameKey: 'payment_method_mpesa',
    subtitleKey: 'mobile_money_wallet_for_east_africa',
    icon: Icons.sim_card_rounded,
    color: Color(0xFF2E7D32),
    valueLabelKey: 'payment_method_mpesa_value_label',
    placeholderKey: 'payment_method_mpesa_placeholder',
    helperTextKey: 'share_the_wallet_number_people_send_to',
    searchTerms: ['mpesa', 'mobile money', 'africa'],
  ),
  PaymentMethodPreset(
    name: 'Bank Transfer',
    nameKey: 'payment_method_bank_transfer',
    subtitleKey: 'iban_account_number_or_routing_details',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF455A64),
    valueLabelKey: 'payment_method_bank_transfer_value_label',
    placeholderKey: 'payment_method_bank_transfer_placeholder',
    helperTextKey: 'use_only_the_details_you_are_comfortable_sharing',
    searchTerms: ['iban', 'account', 'bank transfer'],
  ),
  otherPreset,
];
