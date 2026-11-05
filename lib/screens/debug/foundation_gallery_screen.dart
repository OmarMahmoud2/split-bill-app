import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Debug-only QA gallery of the v3 foundation (tokens, type, shapes, motion,
/// haptics, feedback kit) in light and dark.
///
/// Registered as a route only when [kDebugMode]. Open it with
/// `Navigator.of(context).pushNamed(FoundationGalleryScreen.routeName)` or
/// `flutter run --route=/debug/foundation`. Strings here are deliberately
/// not localized (QA only).
class FoundationGalleryScreen extends StatefulWidget {
  const FoundationGalleryScreen({super.key});

  static const String routeName = '/debug/foundation';

  @override
  State<FoundationGalleryScreen> createState() =>
      _FoundationGalleryScreenState();
}

class _FoundationGalleryScreenState extends State<FoundationGalleryScreen> {
  bool _dark = false;
  bool _reduceMotion = false;
  int _replay = 0;
  int _balance = 6240;
  bool _offline = true;

  @override
  void initState() {
    super.initState();
    _dark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    final theme = _dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    return Theme(
      data: theme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: _reduceMotion),
        child: Builder(builder: _buildBody),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('v3 foundation'),
        actions: [
          IconButton(
            tooltip: 'Toggle dark',
            icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _dark = !_dark),
          ),
          IconButton(
            tooltip: 'Replay animations',
            icon: const Icon(Icons.replay),
            onPressed: () => setState(() => _replay++),
          ),
        ],
      ),
      body: ListView(
        key: ValueKey(_replay),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          SwitchListTile(
            title: const Text('Reduce motion'),
            value: _reduceMotion,
            onChanged: (v) => setState(() => _reduceMotion = v),
          ),
          _section(context, 'PALETTE'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, color) in [
                ('canvas', p.canvas),
                ('surface', p.surface),
                ('surfaceVariant', p.surfaceVariant),
                ('hairline', p.hairline),
                ('borderStrong', p.borderStrong),
                ('ink', p.textPrimary),
                ('muted', p.textSecondary),
                ('tertiary', p.textTertiary),
                ('accent', p.accent),
                ('accentSoft', p.accentSoft),
                ('owe', p.owe),
                ('oweSoft', p.oweSoft),
                ('error', p.error),
                ('info', p.info),
                ('skeleton', p.skeleton),
                ('inverse', p.inverseSurface),
              ])
                _Swatch(name: name, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final tint in p.avatarTints)
                CircleAvatar(
                  radius: 16,
                  backgroundColor: tint,
                  child: Text(
                    'A',
                    style: TextStyle(color: p.textPrimary, fontSize: 12),
                  ),
                ),
            ],
          ),
          _section(context, 'TYPE'),
          Text('\$1,284.50', style: AppTypography.amountHero),
          Text('Display small', style: AppTypography.displaySmall),
          Text('Headline large', style: AppTypography.headlineLarge),
          Text('Headline medium', style: AppTypography.headlineMedium),
          Text('Title large · Inter 600', style: AppTypography.titleLarge),
          Text(
            'Body large · Inter 400 for reading. سارة تدين لك · सारा · ซาร่า',
            style: AppTypography.bodyLarge,
          ),
          Text(
            'Caption 13/18',
            style: AppTypography.caption.copyWith(color: p.textSecondary),
          ),
          _section(context, 'MONEY'),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              MoneyText(minor: 6240, currency: 'USD', sign: MoneySign.always),
              MoneyText(minor: -1500, currency: 'JPY', sign: MoneySign.always),
              MoneyText(minor: 1500, currency: 'KWD', tone: MoneyTone.neutral),
              MoneyText(minor: -8127, currency: 'EGP'),
              MoneyText(minor: 0, currency: 'USD', sign: MoneySign.always),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              MoneyText(
                minor: _balance,
                currency: 'USD',
                sign: MoneySign.always,
                size: MoneySize.large,
                animate: true,
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () =>
                    setState(() => _balance = _balance == 6240 ? -2310 : 6240),
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: RollToZero(
              delay: const Duration(milliseconds: 600),
              from: const MoneyText(
                minor: 4100,
                currency: 'USD',
                sign: MoneySign.always,
                size: MoneySize.large,
              ),
              to: const MoneyText(
                minor: 0,
                currency: 'USD',
                size: MoneySize.large,
              ),
            ),
          ),
          _section(context, 'COMPONENTS'),
          FilledButton(onPressed: () {}, child: const Text('Pill button')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () {}, child: const Text('Secondary')),
          const SizedBox(height: 8),
          TextButton(onPressed: () {}, child: const Text('Text action')),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(labelText: 'Amount', hintText: '0.00'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Selected'),
                selected: true,
                onSelected: (_) {},
              ),
              FilterChip(
                label: const Text('Chip'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
          const Card(
            margin: EdgeInsets.symmetric(vertical: 12),
            child: ListTile(
              title: Text('Hairline card'),
              subtitle: Text('No shadow'),
            ),
          ),
          Row(
            children: [
              FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => const SizedBox(
                    height: 200,
                    child: Center(child: Text('28-radius sheet')),
                  ),
                ),
                child: const Text('Sheet'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Snackbar'),
                    action: SnackBarAction(label: 'Undo', onPressed: () {}),
                  ),
                ),
                child: const Text('Snackbar'),
              ),
            ],
          ),
          _section(context, 'MOTION'),
          for (var i = 0; i < 4; i++)
            StaggeredEntrance(
              index: i,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('Staggered row ${i + 1}'),
              ),
            ),
          Row(
            children: [
              const Text('Fries'),
              const SizedBox(width: 8),
              AvatarHop(
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: p.avatarTints[4],
                  child: Text(
                    'A',
                    style: TextStyle(color: p.textPrimary, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          _section(context, 'HAPTICS'),
          Wrap(
            spacing: 8,
            children: [
              for (final (name, fire) in [
                ('light', AppHaptics.light),
                ('selection', AppHaptics.selection),
                ('success', AppHaptics.success),
                ('warning', AppHaptics.warning),
                ('error', AppHaptics.error),
              ])
                OutlinedButton(onPressed: fire, child: Text(name)),
            ],
          ),
          _section(context, 'TOASTS'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in AppToastType.values)
                OutlinedButton(
                  onPressed: () => AppToast.show(
                    context,
                    message: 'This is a ${type.name} toast',
                    type: type,
                    position: type.index.isEven
                        ? AppToastPosition.bottom
                        : AppToastPosition.top,
                    actionLabel: type == AppToastType.error ? 'Retry' : null,
                    onAction: type == AppToastType.error ? () {} : null,
                  ),
                  child: Text(type.name),
                ),
            ],
          ),
          _section(context, 'STATES'),
          SwitchListTile(
            title: const Text('Offline'),
            value: _offline,
            onChanged: (v) => setState(() => _offline = v),
          ),
          OfflineBanner(visible: _offline, margin: EdgeInsets.zero),
          const SizedBox(height: 12),
          ErrorState.inline(
            title: "We couldn't read this receipt",
            message: 'The photo is too dark. Your credit was refunded.',
            retryLabel: 'Retake photo',
            onRetry: () {},
            secondaryLabel: 'Type it in',
            onSecondary: () {},
          ),
          const SizedBox(height: 12),
          const SkeletonShimmer(
            child: Column(
              children: [
                SkeletonCard(),
                SkeletonListTile(),
                SkeletonListTile(),
              ],
            ),
          ),
          SizedBox(height: 360, child: ErrorState(onRetry: () {})),
          SizedBox(height: 300, child: ErrorState.offline(onRetry: () {})),
          EmptyState(
            icon: Icons.receipt_long_rounded,
            message: 'Scan a receipt to start a bill.',
            actionLabel: 'Scan',
            onAction: () {},
          ),
          _section(context, 'SUCCESS'),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => SuccessScreen.show<void>(
                  context,
                  title: 'Bill sent',
                  message: '4 people can see their share.',
                  amountMinor: 12850,
                  currency: 'USD',
                  primaryLabel: 'Done',
                  onPrimary: () => Navigator.of(context).pop(),
                ),
                child: const Text('Success'),
              ),
              OutlinedButton(
                onPressed: () => SuccessScreen.show<void>(
                  context,
                  title: "Everyone's square",
                  message: '11 bills, 4 people, 3 payments.',
                  caption: 'Dahab trip balance',
                  rollFromMinor: 4100,
                  amountMinor: 0,
                  celebrate: true,
                  primaryLabel: 'Share trip recap',
                  onPrimary: () => Navigator.of(context).pop(),
                  secondaryLabel: 'Archive group',
                  onSecondary: () => Navigator.of(context).pop(),
                ),
                child: const Text('Group settled'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 10),
    child: Text(
      title,
      style: AppTypography.overline.copyWith(
        color: context.palette.textSecondary,
      ),
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hex =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return SizedBox(
      width: 76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadii.rowRadius,
              border: Border.all(color: p.border),
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: AppTypography.labelSmall),
          Text(
            hex,
            style: AppTypography.labelSmall.copyWith(
              color: p.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
