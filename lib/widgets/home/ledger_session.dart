/// Who is signed in and which currency they think in, for ledger screens.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/bill_details_screen.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/participant_bill_screen.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/utils/money_format.dart';

/// The signed-in user as a ledger member.
class LedgerMe {
  const LedgerMe({required this.uid, required this.name, this.photoUrl});
  final String uid;
  final String name;
  final String? photoUrl;

  GroupMember get asMember => GroupMember(id: uid, name: name, photoUrl: photoUrl);

  /// Test hook.
  static LedgerMe? debugOverride;

  static LedgerMe? current() {
    if (debugOverride != null) return debugOverride;
    final uid = LedgerRepository.instance.currentUid;
    if (uid == null) return null;
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    return LedgerMe(
      uid: uid,
      name: user?.displayName ?? '',
      photoUrl: user?.photoURL,
    );
  }
}

/// The user's default currency from settings ("USD" when unavailable).
String preferredCurrency(BuildContext context) {
  try {
    return Provider.of<AppSettingsProvider>(context, listen: false).currencyCode;
  } catch (_) {
    return 'USD';
  }
}

/// Formats an amount for use inside a sentence ("Ali owes me $20.00").
String moneyLabel(BuildContext context, int minor, String currency, {MoneySign sign = MoneySign.none}) {
  String? locale;
  try {
    locale = context.locale.toLanguageTag();
  } catch (_) {
    locale = null;
  }
  return formatMoneyMinor(minor, currency, sign: sign, locale: locale);
}

/// Display name for a person id: "You" for the user.
String personName(String id, String name, String me) {
  if (id == me) return 'you_label'.tr();
  return name.trim().isEmpty ? 'someone_label'.tr() : name;
}

/// Opens a bill the way the rest of the app does (host vs participant).
void openBill(BuildContext context, {required String billId, required String hostId, required String title, required String me}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => hostId == me
          ? BillDetailsScreen(billId: billId, billName: title)
          : ParticipantBillScreen(billId: billId, billName: title),
    ),
  );
}
