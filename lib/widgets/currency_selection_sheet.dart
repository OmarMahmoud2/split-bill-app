import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/theme/app_icons.dart';

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
  }) => PremiumBottomSheet.show<void>(
    context: context,
    isScrollable: true,
    child: CurrencySelectionSheet(
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final query = _search.text.trim().toLowerCase();
    final options = supportedCurrencyOptions.where(
      (option) =>
          '${option.code} ${option.name} ${option.region} ${option.symbol}'
              .toLowerCase()
              .contains(query),
    );
    final decoration = InputDecoration(
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'choose_currency'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('currency-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: decoration.copyWith(
            prefixIcon: const Icon(AppIcons.search),
            hintText: 'settings_search_currency'.tr(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('currency-custom'),
          controller: _custom,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: _select,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: decoration.copyWith(
            labelText: 'settings_custom_currency'.tr(),
            hintText: 'settings_custom_currency_hint'.tr(),
            errorText: _error,
            suffixIcon: IconButton(
              tooltip: 'save_changes'.tr(),
              onPressed: _saving ? null : () => _select(_custom.text),
              icon: const Icon(AppIcons.successFill),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_saving) const LinearProgressIndicator(),
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('no_matches_found'.tr(), textAlign: TextAlign.center),
          ),
        ...options.map((option) {
          final selected = option.code == widget.selectedCode;
          return ListTile(
            key: ValueKey('currency-${option.code}'),
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    option.symbol,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            title: Text(
              option.code,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(option.name),
            trailing: selected
                ? Icon(AppIcons.successFill, color: colors.primary)
                : null,
            onTap: _saving ? null : () => _select(option.code),
          );
        }),
      ],
    );
  }
}
