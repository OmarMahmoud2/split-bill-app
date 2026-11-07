import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/services/public_profile_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

/// Moves the method at [index] to the front: the first saved method is the
/// default shown first on bills and guest links.
List<StoredPaymentMethod> moveMethodToDefault(
  List<StoredPaymentMethod> methods,
  int index,
) {
  if (index <= 0 || index >= methods.length) return [...methods];
  final copy = [...methods];
  final method = copy.removeAt(index);
  return [method, ...copy];
}

/// Suggestions for the "Add" grid: local methods first, without the ones
/// already saved, capped at [limit], with "Other" always last.
List<PaymentMethodType> suggestedMethodsToAdd(
  List<PaymentMethodType> recommended,
  List<StoredPaymentMethod> saved, {
  int limit = 8,
}) {
  final savedIds = {for (final m in saved) m.type.id};
  final list = [
    for (final t in recommended)
      if (t.id != otherPaymentMethod.id && !savedIds.contains(t.id)) t,
  ].take(limit).toList();
  return [...list, otherPaymentMethod];
}

/// True when [value] is acceptable for [type] ("Other" accepts any text).
bool isAcceptableHandle(PaymentMethodType type, String value) {
  if (value.trim().isEmpty) return false;
  if (type.id == otherPaymentMethod.id) return value.trim().length <= 500;
  return type.validateHandle(value);
}

/// Regional-indicator flag for an ISO country code ("EG" -> 🇪🇬).
String countryFlag(String code) {
  final cc = code.toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(cc)) return cc;
  return String.fromCharCodes(cc.codeUnits.map((c) => 0x1F1E6 + c - 0x41));
}

TextInputType _keyboardFor(HandleKind kind) => switch (kind) {
  HandleKind.phone ||
  HandleKind.promptPayId ||
  HandleKind.clabe => TextInputType.phone,
  HandleKind.email || HandleKind.phoneOrEmail => TextInputType.emailAddress,
  HandleKind.url => TextInputType.url,
  HandleKind.accountDetails => TextInputType.multiline,
  _ => TextInputType.text,
};

/// "How friends pay you": saved handles (first = default) plus suggestions
/// for the user's country. Stored as `users/{uid}.customPaymentMethods`
/// (`{name, value, type}`), mirrored to `publicProfiles/{uid}`.
class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({
    super.key,
    @visibleForTesting this.debugInitialMethods,
    @visibleForTesting this.debugPersist,
    @visibleForTesting this.debugLocaleTag,
  });

  /// Skips Firestore and starts with these methods.
  final List<StoredPaymentMethod>? debugInitialMethods;

  /// Replaces the Firestore write.
  final Future<void> Function(List<StoredPaymentMethod> methods)? debugPersist;

  /// Overrides the device locale used to suggest methods.
  final String? debugLocaleTag;

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  List<StoredPaymentMethod> _methods = const [];
  bool _loading = true;
  bool _loadFailed = false;

  bool get _isTest => widget.debugInitialMethods != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isTest) {
      setState(() {
        _methods = [...widget.debugInitialMethods!];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('signed out');
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        _methods = parseStoredPaymentMethods(doc.data());
        _loading = false;
      });
    } catch (e) {
      debugPrint('Payment methods load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<bool> _persist(
    List<StoredPaymentMethod> next, {
    String? successMessage,
    String? undoLabel,
    VoidCallback? onUndo,
  }) async {
    final previous = _methods;
    setState(() => _methods = next);
    try {
      if (widget.debugPersist != null) {
        await widget.debugPersist!(next);
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw StateError('signed out');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'customPaymentMethods': toStoredPaymentMethodList(next)});
        await PublicProfileService.syncFromUserDoc(force: true);
      }
      if (!mounted) return true;
      AppToast.show(
        context,
        message: successMessage ?? 'pm3_saved'.tr(),
        type: AppToastType.success,
        actionLabel: undoLabel,
        onAction: onUndo,
      );
      return true;
    } catch (e) {
      debugPrint('Payment methods save failed: $e');
      if (!mounted) return false;
      setState(() => _methods = previous);
      AppToast.show(
        context,
        message: 'pm3_save_error'.tr(),
        type: AppToastType.error,
      );
      return false;
    }
  }

  String get _localeTag =>
      widget.debugLocaleTag ??
      PlatformDispatcher.instance.locale.toLanguageTag();

  String? _currency(BuildContext context) {
    try {
      return Provider.of<AppSettingsProvider>(
        context,
        listen: false,
      ).currencyCode;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openEditor({PaymentMethodType? type, int? index}) async {
    final existing = index == null ? null : _methods[index];
    final result = await showLedgerSheet<_EditorResult>(
      context,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
        child: _MethodEditor(
          type: existing?.type ?? type!,
          existing: existing,
          isDefault: index == 0,
        ),
      ),
    );
    if (result == null || !mounted) return;
    switch (result.action) {
      case _EditorAction.save:
        final next = [..._methods];
        if (index == null) {
          next.add(result.method!);
        } else {
          next[index] = result.method!;
        }
        await _persist(next);
      case _EditorAction.makeDefault:
        await _persist(moveMethodToDefault(_methods, index!));
      case _EditorAction.delete:
        final removed = _methods[index!];
        final before = [..._methods];
        final next = [..._methods]..removeAt(index);
        await _persist(
          next,
          successMessage: 'pm3_removed'.tr(
            namedArgs: {'method': removed.label},
          ),
          undoLabel: 'pm3_undo'.tr(),
          onUndo: () => _persist(before),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final country = detectPaymentCountry(
      localeTag: _localeTag,
      currency: _currency(context),
    );
    final recommended = recommendedPaymentMethods(
      localeTag: _localeTag,
      currency: _currency(context),
      platform: currentPaymentPlatform(),
    );
    final suggestions = suggestedMethodsToAdd(recommended, _methods);

    Widget body;
    if (_loading) {
      body = const SkeletonShimmer(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              SkeletonListTile(),
              SkeletonListTile(),
              SkeletonListTile(),
            ],
          ),
        ),
      );
    } else if (_loadFailed) {
      body = ErrorState(title: 'pm3_load_error'.tr(), onRetry: _load);
    } else {
      body = ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
            child: Text(
              country == null
                  ? 'pm3_caption'.tr()
                  : 'pm3_caption_country'.tr(
                      namedArgs: {
                        'country': '${countryFlag(country)} $country',
                      },
                    ),
              style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          if (_methods.isEmpty)
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'pm3_empty_title'.tr(),
                        textAlign: TextAlign.center,
                        style: AppTypography.titleMedium.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'pm3_empty_message'.tr(),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            SettingsCard(
              children: [
                for (var i = 0; i < _methods.length; i++)
                  SettingsRow(
                    key: ValueKey('pm3-row-$i'),
                    leading: PaymentMethodLogo(type: _methods[i].type),
                    title: _methods[i].label,
                    subtitle: _methods[i].value,
                    trailing: i == 0 ? SoftChip('pm3_default'.tr()) : null,
                    onTap: () => _openEditor(index: i),
                  ),
              ],
            ),
          OverlineLabel('pm3_add_section'.tr()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final width = (constraints.maxWidth - gap * 2) / 3;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final t in suggestions)
                      SizedBox(
                        width: width,
                        child: _AddTile(
                          key: ValueKey('pm3-add-${t.id}'),
                          type: t,
                          onTap: () => _openEditor(type: t),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            V3TopBar(
              leading: V3IconButton.back(context),
              title: 'payment_methods'.tr(),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Registry logo, or initials on the brand color.
class PaymentMethodLogo extends StatelessWidget {
  const PaymentMethodLogo({super.key, required this.type, this.size = 36});

  final PaymentMethodType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = Color(type.brandColor);
    // Brand tile ink: white or near-black, whichever reads on the brand.
    final ink = ThemeData.estimateBrightnessForColor(brand) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: brand,
      child: Text(
        type.initials,
        maxLines: 1,
        style: AppTypography.labelSmall.copyWith(
          color: ink,
          fontSize: size * 0.33,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: type.logoAsset == null
            ? initials
            : Image.asset(
                type.logoAsset!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initials,
              ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({super.key, required this.type, required this.onTap});

  final PaymentMethodType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = type.id == otherPaymentMethod.id
        ? 'pm3_other'.tr()
        : type.displayName;
    return Semantics(
      button: true,
      label: 'pm3_add_a11y'.tr(namedArgs: {'method': name}),
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: AppRadii.cardShape(p.hairline),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            AppHaptics.light();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  type.id == otherPaymentMethod.id
                      ? Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: p.surfaceVariant,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(AppIcons.add, color: p.textPrimary),
                        )
                      : PaymentMethodLogo(type: type, size: 32),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _EditorAction { save, makeDefault, delete }

class _EditorResult {
  const _EditorResult(this.action, [this.method]);
  final _EditorAction action;
  final StoredPaymentMethod? method;
}

class _MethodEditor extends StatefulWidget {
  const _MethodEditor({
    required this.type,
    required this.existing,
    required this.isDefault,
  });

  final PaymentMethodType type;
  final StoredPaymentMethod? existing;
  final bool isDefault;

  @override
  State<_MethodEditor> createState() => _MethodEditorState();
}

class _MethodEditorState extends State<_MethodEditor> {
  late final TextEditingController _value;
  late final TextEditingController _label;
  late HandleKind _kind;
  String? _error;

  bool get _isOther => widget.type.id == otherPaymentMethod.id;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _value = TextEditingController(text: existing?.value ?? '');
    _label = TextEditingController(
      text: _isOther ? (existing?.label ?? '') : '',
    );
    _kind = existing == null
        ? widget.type.primaryHandleKind
        : (widget.type.kindFor(existing.value) ??
              widget.type.primaryHandleKind);
    if (!widget.type.handleKinds.contains(_kind)) {
      _kind = widget.type.primaryHandleKind;
    }
  }

  @override
  void dispose() {
    _value.dispose();
    _label.dispose();
    super.dispose();
  }

  void _save() {
    final value = _value.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'pm3_required'.tr());
      AppHaptics.error();
      return;
    }
    if (!isAcceptableHandle(widget.type, value)) {
      setState(
        () => _error = 'pm3_invalid_handle'.tr(
          namedArgs: {'kind': _kind.labelKey.tr()},
        ),
      );
      AppHaptics.error();
      return;
    }
    AppHaptics.success();
    final label = _isOther
        ? _label.text.trim()
        : (widget.existing?.label ?? widget.type.displayName);
    Navigator.of(context).pop(
      _EditorResult(
        _EditorAction.save,
        StoredPaymentMethod.create(widget.type, value, label: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = _isOther ? 'pm3_other'.tr() : widget.type.displayName;
    final editing = widget.existing != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PaymentMethodLogo(type: widget.type, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    editing
                        ? 'edit_payment_method'.tr()
                        : 'add_payment_method'.tr(),
                    style: AppTypography.headlineMedium.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                  Text(
                    '$name · ${widget.type.descriptionKey.tr()}',
                    style: AppTypography.bodySmall.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_isOther) ...[
          V3FieldLabel('custom_method_name'.tr()),
          TextField(
            key: const ValueKey('pm3-label'),
            controller: _label,
            textInputAction: TextInputAction.next,
            maxLength: 40,
          ),
          const SizedBox(height: 8),
        ],
        if (widget.type.handleKinds.length > 1) ...[
          V3FieldLabel('pm3_handle_type'.tr()),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in widget.type.handleKinds)
                V3ChoiceChip(
                  label: k.labelKey.tr(),
                  selected: k == _kind,
                  onTap: () => setState(() {
                    _kind = k;
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        V3FieldLabel(_kind.labelKey.tr()),
        TextField(
          key: const ValueKey('pm3-value'),
          controller: _value,
          autofocus: !editing,
          keyboardType: _keyboardFor(_kind),
          maxLines: _kind == HandleKind.accountDetails ? 4 : 1,
          minLines: 1,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [LengthLimitingTextInputFormatter(500)],
          textInputAction: _kind == HandleKind.accountDetails
              ? TextInputAction.newline
              : TextInputAction.done,
          onSubmitted: (_) => _save(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(errorText: _error),
        ),
        const SizedBox(height: 6),
        Text(
          'pm3_visible_note'.tr(),
          style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('pm3-save'),
          onPressed: _save,
          child: Text('pm3_save'.tr()),
        ),
        if (editing && !widget.isDefault) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            key: const ValueKey('pm3-make-default'),
            onPressed: () => Navigator.of(
              context,
            ).pop(const _EditorResult(_EditorAction.makeDefault)),
            child: Text('pm3_make_default'.tr()),
          ),
        ],
        if (editing) ...[
          const SizedBox(height: 4),
          TextButton(
            key: const ValueKey('pm3-delete'),
            style: TextButton.styleFrom(foregroundColor: p.error),
            onPressed: () {
              AppHaptics.warning();
              Navigator.of(
                context,
              ).pop(const _EditorResult(_EditorAction.delete));
            },
            child: Text('common_delete'.tr()),
          ),
        ],
      ],
    );
  }
}
