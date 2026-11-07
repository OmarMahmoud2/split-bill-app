import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/screens/split_bill/widgets/add_members_sheet.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_logic.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_sheets.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/plural_text.dart';
import 'package:split_bill_app/widgets/app_text_field.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';

/// A group the host belongs to, as offered on the add-people step.
class AddPeopleGroup {
  const AddPeopleGroup({
    required this.id,
    required this.name,
    required this.members,
  });

  final String id;
  final String name;

  /// Legacy member maps (`id`, `name`, `phoneNumber`, `photoUrl`, `isGuest`).
  final List<Map<String, dynamic>> members;
}

/// Adds people found by a source (QR, contacts). Returns the participant
/// maps to add (possibly empty); shows its own feedback on failure.
typedef AddPeopleSource =
    Future<List<Map<String, dynamic>>> Function(BuildContext context);

/// "Who was there?" (People board 1): search, selected chips, Scan QR /
/// Contacts / Add guest, and the host's group members with checkboxes.
/// Pops the final participant list (host first), or null when backed out.
class AddPeopleScreen extends StatefulWidget {
  const AddPeopleScreen({
    super.key,
    required this.initialParticipants,
    this.groups,
    this.onScanQr,
    this.onPickContacts,
  });

  /// Current bill participants; the host (`isHost`) cannot be removed.
  final List<Map<String, dynamic>> initialParticipants;

  /// The host's groups; null hides the section.
  final Stream<List<AddPeopleGroup>>? groups;
  final AddPeopleSource? onScanQr;
  final AddPeopleSource? onPickContacts;

  static Future<List<Map<String, dynamic>>?> open(
    BuildContext context, {
    required List<Map<String, dynamic>> participants,
    Stream<List<AddPeopleGroup>>? groups,
    AddPeopleSource? onScanQr,
    AddPeopleSource? onPickContacts,
  }) => Navigator.of(context).push<List<Map<String, dynamic>>>(
    MaterialPageRoute(
      builder: (_) => AddPeopleScreen(
        initialParticipants: participants,
        groups: groups,
        onScanQr: onScanQr,
        onPickContacts: onPickContacts,
      ),
    ),
  );

  @override
  State<AddPeopleScreen> createState() => _AddPeopleScreenState();
}

class _AddPeopleScreenState extends State<AddPeopleScreen> {
  final _search = TextEditingController();
  late final List<Map<String, dynamic>> _selected;

  /// People added from a source on this screen (QR, contacts, guests) that
  /// are not in a group: listed under "Added".
  final List<Map<String, dynamic>> _added = [];
  StreamSubscription<List<AddPeopleGroup>>? _sub;
  List<AddPeopleGroup>? _groups;
  bool _groupsFailed = false;
  bool _busy = false;

  /// People you already split with, built once so guest ids stay stable.
  late final List<Map<String, dynamic>> _recent = _buildRecent();

  List<Map<String, dynamic>> _buildRecent() {
    final names = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final c in HomeBalances.latest?.summary.people ?? const []) {
      final name = c.name.trim();
      if (name.isEmpty || !names.add(name.toLowerCase())) continue;
      // A past guest comes back as a new guest with the same name: guest ids
      // belong to the bill they were added on.
      final isGuest = c.id.isEmpty || c.id.startsWith('guest_');
      out.add(
        isGuest
            ? participantFromProfile({'name': name}, isGuest: true)
            : participantFromProfile({
                'id': c.id,
                'name': name,
                'photoUrl': c.photoUrl ?? '',
              }),
      );
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _selected = [
      for (final x in widget.initialParticipants) Map<String, dynamic>.of(x),
    ];
    _added.addAll(_selected.where((x) => x['isHost'] != true));
    _listen();
  }

  void _listen() {
    _sub?.cancel();
    final stream = widget.groups;
    if (stream == null) return;
    _sub = stream.listen(
      (groups) {
        if (mounted) {
          setState(() {
            _groups = groups;
            _groupsFailed = false;
          });
        }
      },
      onError: (Object _) {
        if (mounted) setState(() => _groupsFailed = true);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _search.dispose();
    super.dispose();
  }

  String _id(Map<String, dynamic> x) => x['id'].toString();

  bool _isSelected(String id) => _selected.any((x) => _id(x) == id);

  void _toggle(Map<String, dynamic> person) {
    final id = _id(person);
    setState(() {
      if (_isSelected(id)) {
        _selected.removeWhere((x) => _id(x) == id && x['isHost'] != true);
      } else {
        _selected.add(Map<String, dynamic>.of(person));
      }
    });
    AppHaptics.selection();
  }

  void _addPeople(List<Map<String, dynamic>> people) {
    var added = 0;
    var duplicate = false;
    setState(() {
      for (final person in people) {
        final id = _id(person);
        if (_isSelected(id)) {
          duplicate = true;
          continue;
        }
        _selected.add(person);
        if (!_inGroups(id) && !_added.any((x) => _id(x) == id)) {
          _added.add(person);
        }
        added++;
      }
    });
    if (added > 0) {
      AppHaptics.success();
      AppToast.show(
        context,
        message: 'added_people_count'.tr(namedArgs: {'count': '$added'}),
        type: AppToastType.success,
      );
    } else if (duplicate) {
      AppToast.show(
        context,
        message: 'user_already_in_bill'.tr(),
        type: AppToastType.info,
      );
    }
  }

  bool _inGroups(String id) =>
      (_groups ?? const []).any((g) => g.members.any((m) => _id(m) == id));

  Future<void> _runSource(AddPeopleSource? source) async {
    if (source == null || _busy) return;
    setState(() => _busy = true);
    try {
      final people = await source(context);
      if (!mounted) return;
      _addPeople(people);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addGuest([String? prefill]) async {
    final name = prefill ?? await AddGuestSheet.show(context);
    if (!mounted || name == null || name.trim().isEmpty) return;
    _search.clear();
    _addPeople([guestParticipant(name)]);
  }

  bool _matches(Map<String, dynamic> person, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    for (final key in ['name', 'phoneNumber', 'email']) {
      final value = (person[key] ?? '').toString().toLowerCase();
      if (value.contains(q)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final query = _search.text.trim();
    final hostIds = {
      for (final x in _selected)
        if (x['isHost'] == true) _id(x),
    };

    // Each person once: group sections first, then "Added".
    final seen = <String>{...hostIds};
    final groupCounts = <String, int>{};
    for (final g in _groups ?? const <AddPeopleGroup>[]) {
      for (final m in g.members) {
        groupCounts[_id(m)] = (groupCounts[_id(m)] ?? 0) + 1;
      }
    }
    final sections = <({String title, List<Map<String, dynamic>> people})>[];
    for (final g in _groups ?? const <AddPeopleGroup>[]) {
      final people = <Map<String, dynamic>>[];
      for (final m in g.members) {
        final id = _id(m);
        if (seen.contains(id)) continue;
        seen.add(id);
        if (_matches(m, query)) people.add(m);
      }
      if (people.isNotEmpty) {
        sections.add((
          title: 'bf_assign_from_group'.tr(namedArgs: {'group': g.name}),
          people: people,
        ));
      }
    }
    // People you already split with, one tap away (no searching each time).
    final selectedNames = {
      for (final x in _selected) x['name'].toString().trim().toLowerCase(),
    };
    final recent = [
      for (final m in _recent)
        if (!seen.contains(_id(m)) &&
            // Name match hides only past guests; a registered namesake stays.
            !(m['isGuest'] == true &&
                selectedNames.contains(
                  m['name'].toString().trim().toLowerCase(),
                )) &&
            _matches(m, query))
          m,
    ];
    seen.addAll(recent.map(_id));
    if (recent.isNotEmpty) {
      sections.add((title: 'home_your_people'.tr(), people: recent));
    }
    final added = [
      for (final m in _added)
        if (!seen.contains(_id(m)) && _matches(m, query)) m,
    ];
    if (added.isNotEmpty) {
      sections.insert(0, (
        title: 'bf_assign_added_section'.tr(),
        people: added,
      ));
    }

    return Scaffold(
      backgroundColor: p.background,
      body: AdaptiveBody.form(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'back'.tr(),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(AppIcons.back, color: p.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'bf_assign_who_was_there'.tr(),
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 24,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 20),
                  children: [
                    AppTextField(
                      key: const ValueKey('bf_assign_people_search'),
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      hint: 'bf_assign_search_hint'.tr(),
                      prefix: Icon(AppIcons.search, color: p.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PersonGrid(
                      children: [
                        for (final person in _selected)
                          PersonTile(
                            key: ValueKey('bf_assign_selected_${_id(person)}'),
                            person: person,
                            selected: true,
                            isYou: person['isHost'] == true,
                            onTap: person['isHost'] == true
                                ? null
                                : () => _toggle(person),
                          ),
                        GuestTile(onTap: _addGuest),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.onScanQr != null) ...[
                          Expanded(
                            child: AddSourceCard(
                              icon: AppIcons.qr,
                              label: 'scan_qr'.tr(),
                              onTap: () => _runSource(widget.onScanQr),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        if (widget.onPickContacts != null) ...[
                          Expanded(
                            child: AddSourceCard(
                              icon: AppIcons.contacts,
                              label: 'contacts'.tr(),
                              onTap: () => _runSource(widget.onPickContacts),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                      ],
                    ),
                    if (_busy) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const SkeletonShimmer(
                        child: Column(
                          children: [SkeletonListTile(), SkeletonListTile()],
                        ),
                      ),
                    ],
                    if (query.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: _AddQueryAsGuest(
                          name: query,
                          onTap: () => _addGuest(query),
                        ),
                      ),
                    for (final section in sections)
                      if (section.people.any((m) => !_isSelected(_id(m)))) ...[
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            0,
                            20,
                            0,
                            10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  section.title,
                                  style: AppTypography.titleSmall.copyWith(
                                    color: p.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _UseGroupChip(
                                onTap: () => _addPeople([
                                  for (final m in section.people)
                                    if (!_isSelected(_id(m))) m,
                                ]),
                              ),
                            ],
                          ),
                        ),
                        PersonGrid(
                          children: [
                            for (final m in section.people)
                              if (!_isSelected(_id(m)))
                                PersonTile(
                                  key: ValueKey(
                                    'bf_assign_person_row_${m['id']}',
                                  ),
                                  person: m,
                                  selected: false,
                                  onTap: () => _toggle(m),
                                ),
                          ],
                        ),
                      ],
                    if (widget.groups != null &&
                        _groups == null &&
                        !_groupsFailed) ...[
                      const SizedBox(height: AppSpacing.xl),
                      const SkeletonShimmer(
                        child: Column(
                          children: [
                            SkeletonListTile(),
                            SkeletonListTile(),
                            SkeletonListTile(),
                          ],
                        ),
                      ),
                    ],
                    if (_groupsFailed) ...[
                      const SizedBox(height: AppSpacing.xl),
                      ErrorState.inline(
                        title: 'bf_assign_groups_error_title'.tr(),
                        message: 'bf_assign_groups_error_message'.tr(),
                        onRetry: () {
                          setState(() => _groupsFailed = false);
                          _listen();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
                child: AssignPillButton(
                  key: const ValueKey('bf_assign_people_continue'),
                  label: pluralText('bf_continue_people', _selected.length),
                  onPressed: () {
                    AppHaptics.light();
                    Navigator.of(
                      context,
                    ).pop(List<Map<String, dynamic>>.of(_selected));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddQueryAsGuest extends StatelessWidget {
  const _AddQueryAsGuest({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: AppRadii.rowShape(p.border),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(AppIcons.personAdd, color: p.primaryStrong),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'bf_assign_add_query_as_guest'.tr(namedArgs: {'name': name}),
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 15,
                    color: p.primaryStrong,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PersonGrid extends StatelessWidget {
  const PersonGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 14, children: children);
}

/// Selectable pal avatar: mint ring and a check badge when selected.
class PersonTile extends StatelessWidget {
  const PersonTile({
    super.key,
    required this.person,
    required this.selected,
    required this.onTap,
    this.isYou = false,
  });

  final Map<String, dynamic> person;
  final bool selected;
  final bool isYou;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = firstNameOf(person['name']);
    // A 72 pt tile has no room for "Omar (you)": just "You".
    final name = isYou ? 'home_tab_you'.tr() : first;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: (person['name'] ?? '').toString(),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  PalAvatar(
                    seed: (person['id'] ?? person['name'] ?? '')
                        .toString()
                        .toLowerCase(),
                    name: person['name']?.toString(),
                    photoUrl: person['photoUrl']?.toString(),
                    size: 56,
                    ringColor: selected ? p.accent : null,
                  ),
                  if (selected)
                    PositionedDirectional(
                      end: -2,
                      bottom: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.background, width: 2),
                        ),
                        child: Icon(AppIcons.check, size: 12, color: p.onMint),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(
                  color: p.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed "Guest" add tile.
class GuestTile extends StatelessWidget {
  const GuestTile({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'bf_assign_add_guest'.tr(),
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          AppHaptics.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              CustomPaint(
                painter: _DashedCirclePainter(p.borderStrong),
                child: SizedBox.square(
                  dimension: 56,
                  child: Icon(AppIcons.add, color: p.textSecondary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'bf_assign_guest_tile'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = size.width / 2 - 1;
    const dashes = 18;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: r),
        i * 2 * 3.14159265 / dashes,
        3.14159265 / dashes,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

class _UseGroupChip extends StatelessWidget {
  const _UseGroupChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.fullRadius,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.accentSoft,
          borderRadius: AppRadii.fullRadius,
        ),
        child: Text(
          'bf_assign_use_group'.tr(),
          style: AppTypography.labelMedium.copyWith(
            color: p.onAccentSoft,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
