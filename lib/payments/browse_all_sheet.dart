import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart' as phone;
import 'package:split_bill_app/payment_settings_screen.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';

/// A group of methods under one region heading.
class MethodGroup {
  const MethodGroup(this.label, this.methods);
  final String label;
  final List<PaymentMethodType> methods;
}

/// Every selectable method (no "Other").
List<PaymentMethodType> browsableMethods({PaymentPlatform? platform}) => [
  for (final t in paymentMethodRegistry)
    if (t.id != otherPaymentMethod.id &&
        (platform == null || t.isAvailableOn(platform)))
      t,
];

/// Real coverage numbers from the registry: apps and distinct countries.
({int apps, int countries}) paymentCoverage() => (
  apps: browsableMethods().length,
  countries: {for (final t in browsableMethods()) ...t.countries}.length,
);

/// "80+" style label: the real count floored to the nearest ten.
String roundedPlus(int n) => '${n >= 10 ? (n ~/ 10) * 10 : n}+';

String countryDisplayName(String code, String lang) {
  for (final c in phone.countries) {
    if (c.code == code) return c.localizedName(lang);
  }
  return code;
}

/// Methods grouped Worldwide, then by country (A-Z), then multi-country
/// ones, filtered by [query] on name, aliases, country code or name.
List<MethodGroup> groupMethods(
  List<PaymentMethodType> all, {
  String query = '',
  String lang = 'en',
  String worldwideLabel = 'Worldwide',
  String multiLabel = 'Several countries',
}) {
  final q = query.trim().toLowerCase();
  bool matches(PaymentMethodType t) {
    if (q.isEmpty) return true;
    final hay = [
      t.displayName,
      ...t.aliases,
      for (final c in t.countries) ...[c, countryDisplayName(c, lang)],
    ];
    return hay.any((s) => s.toLowerCase().contains(q));
  }

  final world = <PaymentMethodType>[];
  final multi = <PaymentMethodType>[];
  final byCountry = <String, List<PaymentMethodType>>{};
  for (final t in all.where(matches)) {
    if (t.countries.isEmpty) {
      world.add(t);
    } else if (t.countries.length > 3) {
      multi.add(t);
    } else {
      for (final c in t.countries) {
        (byCountry[c] ??= []).add(t);
      }
    }
  }
  final codes = byCountry.keys.toList()
    ..sort(
      (a, b) =>
          countryDisplayName(a, lang).compareTo(countryDisplayName(b, lang)),
    );
  return [
    if (world.isNotEmpty) MethodGroup(worldwideLabel, world),
    for (final c in codes)
      MethodGroup(
        '${countryFlag(c)} ${countryDisplayName(c, lang)}',
        byCountry[c]!,
      ),
    if (multi.isNotEmpty) MethodGroup(multiLabel, multi),
  ];
}

/// Opens the searchable "all payment methods" sheet; resolves to the picked
/// method, or null.
Future<PaymentMethodType?> showBrowseAllMethods(
  BuildContext context, {
  PaymentPlatform? platform,
}) {
  return showLedgerSheet<PaymentMethodType>(
    context,
    title: 'yx_pay_all_title'.tr(),
    builder: (_) => _BrowseBody(platform: platform),
  );
}

class _BrowseBody extends StatefulWidget {
  const _BrowseBody({this.platform});
  final PaymentPlatform? platform;

  @override
  State<_BrowseBody> createState() => _BrowseBodyState();
}

class _BrowseBodyState extends State<_BrowseBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final groups = groupMethods(
      browsableMethods(platform: widget.platform),
      query: _query,
      lang: context.locale.languageCode,
      worldwideLabel: 'yx_pay_worldwide'.tr(),
      multiLabel: 'yx_pay_multi'.tr(),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
          child: TextField(
            key: const ValueKey('pm-browse-search'),
            autocorrect: false,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'yx_pay_search'.tr(),
              prefixIcon: Icon(AppIcons.search, color: p.accent, size: 20),
            ),
          ),
        ),
        Flexible(
          child: groups.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'yx_pay_none'.tr(),
                    style: AppTypography.bodyMedium.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    for (final g in groups) ...[
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          24,
                          14,
                          24,
                          6,
                        ),
                        child: Text(
                          g.label,
                          style: AppTypography.labelLarge.copyWith(
                            color: p.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final t in g.methods)
                        ListTile(
                          key: ValueKey('pm-browse-${g.label}-${t.id}'),
                          leading: PaymentMethodLogo(type: t),
                          title: Text(t.displayName),
                          onTap: () {
                            AppHaptics.light();
                            Navigator.of(context).pop(t);
                          },
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
