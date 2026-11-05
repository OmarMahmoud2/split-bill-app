/// Maps payment methods stored before 2.0 onto registry types.
///
/// Storage stays backward compatible:
/// * `users/{uid}.customPaymentMethods` and
///   `publicProfiles/{uid}.customPaymentMethods`: list of
///   `{name, value}`; 2.0 adds an optional `type` (registry id). Older apps
///   ignore it and keep reading `name`/`value`.
/// * `users/{uid}.paymentMethods` (pre-1.0): map `{key: value}`.
/// * `bills/{id}.paymentMethods`: map `{name: value}` copied at bill creation.
///
/// Pure Dart.
library;

import 'bank_formats.dart';
import 'payment_method_type.dart';
import 'payment_models.dart';

/// A recipient's saved method resolved against the registry.
class StoredPaymentMethod {
  const StoredPaymentMethod({
    required this.type,
    required this.label,
    required this.value,
  });

  /// Builds a new entry for [type] (label defaults to its display name).
  factory StoredPaymentMethod.create(
    PaymentMethodType type,
    String value, {
    String? label,
  }) => StoredPaymentMethod(
    type: type,
    label: (label == null || label.trim().isEmpty) ? type.displayName : label,
    value: value.trim(),
  );

  final PaymentMethodType type;

  /// The name shown to people (kept verbatim from old data).
  final String label;

  /// The stored handle, verbatim.
  final String value;

  /// Whether [value] passes the type's validation.
  bool get isValid => type.validateHandle(value);

  /// Canonical handle for links.
  String get handle => type.normalizeHandle(value);

  /// Builds the tap action for paying [amount].
  PaymentLaunch launch(PaymentRequest Function(String handle) request) =>
      type.buildLaunch(request(value));

  /// Firestore shape: legacy keys plus `type`.
  Map<String, String> toStorage() => {
    'name': label,
    'value': value,
    'type': type.id,
  };

  @override
  String toString() => 'StoredPaymentMethod(${type.id}, $label, $value)';
}

/// Resolves a legacy `{name, value}` (and optional `type`) to a registry type.
StoredPaymentMethod adaptLegacyPaymentMethod(
  String name,
  String value, {
  String? typeId,
}) {
  final explicit = paymentMethodById(typeId);
  if (explicit != null) {
    return StoredPaymentMethod(type: explicit, label: name, value: value);
  }
  final byName = _matchByName(name);
  // "Other" says nothing about the provider: let the value decide.
  final type = (byName == null || byName == otherPaymentMethod)
      ? (_matchByValue(value) ?? otherPaymentMethod)
      : byName;
  final label = name.trim().isEmpty
      ? type.displayName
      // Pre-1.0 map keys were stored upper-cased ("INSTAPAY"): prettify those.
      : (name == name.toUpperCase() && type != otherPaymentMethod
            ? type.displayName
            : name.trim());
  return StoredPaymentMethod(type: type, label: label, value: value);
}

String _squash(String s) =>
    s.toLowerCase().replaceAll(RegExp(r"[\s_\-'.]+"), '');

PaymentMethodType? _matchByName(String name) {
  final n = _squash(name);
  if (n.isEmpty) return null;
  // Exact id or alias first, then "contains" so "My PayPal" still matches.
  final direct = paymentMethodById(
    name.trim().toLowerCase().replaceAll(' ', '_'),
  );
  if (direct != null) return direct;
  final words = name
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .toSet();
  final plain = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final oneWord = !plain.contains(' ');
  PaymentMethodType? best;
  var bestLength = 0;
  for (final type in paymentMethodRegistry) {
    for (final alias in [...type.aliases, type.displayName]) {
      final a = _squash(alias);
      if (a.isEmpty) continue;
      // "Pay me" is a phrase, not PayMe: squashed equality only for one word.
      if (n == a && (oneWord || alias.toLowerCase() == plain)) return type;
      // Short aliases ("upi", "pix") must be a whole word; longer ones may
      // sit inside one word ("mypaypal") but never span words ("pay me").
      final phrase = ' $plain '.contains(' ${alias.toLowerCase()} ');
      final hit =
          phrase ||
          (a.length >= 4 ? words.any((w) => w.contains(a)) : words.contains(a));
      if (hit && a.length > bestLength) {
        best = type;
        bestLength = a.length;
      }
    }
  }
  return best;
}

PaymentMethodType? _matchByValue(String value) {
  final v = value.trim();
  if (v.isEmpty) return null;
  for (final type in paymentMethodRegistry) {
    if (type.linkHandle(v) != null) return type;
  }
  final lower = v.toLowerCase();
  if (lower.contains('instapay') || lower.contains('ipn.eg')) {
    return paymentMethodById('instapay');
  }
  if (upiVpaPattern.hasMatch(v) && !v.contains('.')) {
    return paymentMethodById('upi');
  }
  if (RegExp(r'^\$[A-Za-z]').hasMatch(v)) return paymentMethodById('cash_app');
  if (isValidIban(v)) return paymentMethodById('bank_transfer');
  return null;
}

/// Reads a user or public-profile document: prefers `customPaymentMethods`
/// (list), falls back to the pre-1.0 `paymentMethods` map. Empty values are
/// dropped.
List<StoredPaymentMethod> parseStoredPaymentMethods(Map<String, dynamic>? doc) {
  if (doc == null) return const [];
  final list = doc['customPaymentMethods'];
  if (list is List && list.isNotEmpty) {
    return [
      for (final entry in list)
        if (entry is Map)
          if ((entry['value']?.toString().trim() ?? '').isNotEmpty)
            adaptLegacyPaymentMethod(
              entry['name']?.toString() ?? '',
              entry['value'].toString(),
              typeId: entry['type']?.toString(),
            ),
    ];
  }
  final map = doc['paymentMethods'];
  if (map is Map) return parseBillPaymentMethods(map);
  return const [];
}

/// Reads a bill's `paymentMethods` map (`{name: value}`).
List<StoredPaymentMethod> parseBillPaymentMethods(Map<dynamic, dynamic>? map) {
  if (map == null) return const [];
  return [
    for (final entry in map.entries)
      if ((entry.value?.toString().trim() ?? '').isNotEmpty)
        adaptLegacyPaymentMethod(entry.key.toString(), entry.value.toString()),
  ];
}

/// Serialises methods for `customPaymentMethods`.
List<Map<String, String>> toStoredPaymentMethodList(
  Iterable<StoredPaymentMethod> methods,
) => [for (final m in methods) m.toStorage()];
