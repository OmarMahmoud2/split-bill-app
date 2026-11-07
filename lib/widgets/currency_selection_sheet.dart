import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/app_text_field.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/motion/motion.dart';

/// The same searchable currency picker used during setup and in Settings.
class CurrencySelectionSheet extends StatefulWidget {
  const CurrencySelectionSheet({
    super.key,
    required this.selectedCode,
    required this.onSelected,
  });

  final String selectedCode;
  final FutureOr<void> Function(String code) onSelected;

  static Future<void> show({
    required BuildContext context,
    required String selectedCode,
    required FutureOr<void> Function(String code) onSelected,
  }) => showLedgerSheet<void>(
    context,
    title: 'choose_currency'.tr(),
    builder: (_) => CurrencySelectionSheet(
      selectedCode: selectedCode,
      onSelected: onSelected,
    ),
  );

  @override
  State<CurrencySelectionSheet> createState() => _CurrencySelectionSheetState();
}

class _CurrencySelectionSheetState extends State<CurrencySelectionSheet> {
  final _search = TextEditingController();
  final _custom = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _select(String code) async {
    if (_saving) return;
    final normalized = sanitizeCurrencyCode(code);
    if (normalized == null) {
      setState(() => _error = 'onboarding_custom_currency_error'.tr());
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSelected(normalized);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'onboarding_save_error'.tr();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final query = _search.text.trim().toLowerCase();
    final options = supportedCurrencyOptions.where(
      (option) =>
          '${option.code} ${option.name} ${option.region} ${option.symbol}'
              .toLowerCase()
              .contains(query),
    );

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            key: const ValueKey('currency-search'),
            controller: _search,
            hint: 'settings_search_currency'.tr(),
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            prefix: Icon(AppIcons.search, color: p.accent, size: 20),
          ),
          const SizedBox(height: 12),
          AppTextField(
            key: const ValueKey('currency-custom'),
            controller: _custom,
            label: 'settings_custom_currency'.tr(),
            hint: 'settings_custom_currency_hint'.tr(),
            errorText: _error,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: _select,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            suffix: IconButton(
              tooltip: 'save_changes'.tr(),
              visualDensity: VisualDensity.compact,
              onPressed: _saving ? null : () => _select(_custom.text),
              icon: Icon(AppIcons.successFill, color: p.accent),
            ),
          ),
          const SizedBox(height: 16),
          if (_saving) const LinearProgressIndicator(),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'no_matches_found'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
          ...options.map((option) {
            final selected = option.code == widget.selectedCode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Pressable(
                key: ValueKey('currency-${option.code}'),
                onTap: _saving ? null : () => _select(option.code),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? p.accentSoft : p.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? p.accent : p.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? p.surface : p.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              option.symbol,
                              style: AppTypography.amount.copyWith(
                                color: p.accent,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
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
                              option.code,
                              style: AppTypography.titleMedium.copyWith(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              option.name,
                              style: AppTypography.bodySmall.copyWith(
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected) Icon(AppIcons.successFill, color: p.accent),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
