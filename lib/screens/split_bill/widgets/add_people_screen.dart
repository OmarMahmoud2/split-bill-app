import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/screens/split_bill/widgets/add_members_sheet.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assign_widgets.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_logic.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_sheets.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

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

    String subtitleFor(Map<String, dynamic> person) {
      if (person['isGuest'] == true) return 'bf_assign_guest_no_app'.tr();
      final n = groupCounts[_id(person)] ?? 0;
      if (n == 1) return 'bf_assign_in_one_group'.tr();
      if (n > 1) {
        return 'bf_assign_in_groups'.tr(namedArgs: {'count': '$n'});
      }
      return (person['phoneNumber'] ?? '').toString();
    }

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
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
                    icon: Icon(
                      Icons.adaptive.arrow_back_rounded,
                      color: p.textPrimary,
                    ),
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                children: [
                  TextField(
                    key: const ValueKey('bf_assign_people_search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'bf_assign_search_hint'.tr(),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: p.textSecondary,
                      ),
                      filled: true,
                      fillColor: p.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: AppRadii.rowRadius,
                        borderSide: BorderSide(color: p.borderStrong),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadii.rowRadius,
                        borderSide: BorderSide(color: p.borderStrong),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadii.rowRadius,
                        borderSide: BorderSide(color: p.accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final person in _selected)
                        _SelectedChip(
                          key: ValueKey('bf_assign_selected_${_id(person)}'),
                          participant: person,
                          onRemove: person['isHost'] == true
                              ? null
                              : () => _toggle(person),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.onScanQr != null) ...[
                        Expanded(
                          child: AddSourceCard(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'scan_qr'.tr(),
                            onTap: () => _runSource(widget.onScanQr),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      if (widget.onPickContacts != null) ...[
                        Expanded(
                          child: AddSourceCard(
                            icon: Icons.contacts_outlined,
                            label: 'contacts'.tr(),
                            onTap: () => _runSource(widget.onPickContacts),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: AddSourceCard(
                          icon: Icons.person_add_alt_outlined,
                          label: 'bf_assign_add_guest'.tr(),
                          onTap: _addGuest,
                        ),
                      ),
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
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                      child: Text(
                        section.title.toUpperCase(),
                        style: AppTypography.overline.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ),
                    _PeopleCard(
                      people: section.people,
                      isSelected: (m) => _isSelected(_id(m)),
                      subtitleFor: subtitleFor,
                      onToggle: _toggle,
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AssignPillButton(
                key: const ValueKey('bf_assign_people_continue'),
                label: 'bf_assign_continue_with'.tr(
                  namedArgs: {'count': '${_selected.length}'},
                ),
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
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({super.key, required this.participant, this.onRemove});

  final Map<String, dynamic> participant;

  /// Null for the host.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isHost = onRemove == null;
    final name = firstNameOf(participant['name']);
    final label = isHost
        ? 'bf_assign_you_chip'.tr(namedArgs: {'name': name})
        : name;
    final chip = Container(
      height: 34,
      padding: EdgeInsetsDirectional.only(start: 12, end: isHost ? 12 : 6),
      decoration: BoxDecoration(
        color: isHost
            ? p.inverseSurface
            : p.avatarTintFor(participant['id'].toString()),
        borderRadius: AppRadii.fullRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isHost ? p.onInverseSurface : p.textPrimary,
            ),
          ),
          if (!isHost) ...[
            const SizedBox(width: 2),
            Icon(Icons.close_rounded, size: 16, color: p.textPrimary),
          ],
        ],
      ),
    );
    if (isHost) return chip;
    return Semantics(
      button: true,
      label: 'bf_assign_remove_person'.tr(
        namedArgs: {'name': (participant['name'] ?? '').toString()},
      ),
      excludeSemantics: true,
      child: InkWell(
        onTap: onRemove,
        borderRadius: AppRadii.fullRadius,
        child: Padding(
          // Keeps the 44 pt touch target around the 34 pt chip.
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: chip,
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
              Icon(Icons.person_add_alt_outlined, color: p.primaryStrong),
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

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({
    required this.people,
    required this.isSelected,
    required this.subtitleFor,
    required this.onToggle,
  });

  final List<Map<String, dynamic>> people;
  final bool Function(Map<String, dynamic>) isSelected;
  final String Function(Map<String, dynamic>) subtitleFor;
  final ValueChanged<Map<String, dynamic>> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: AppRadii.cardShape(p.border),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < people.length; i++)
            Semantics(
              checked: isSelected(people[i]),
              button: true,
              child: InkWell(
                key: ValueKey('bf_assign_person_row_${people[i]['id']}'),
                onTap: () => onToggle(people[i]),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 62),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    border: i > 0
                        ? Border(top: BorderSide(color: p.borderSubtle))
                        : null,
                  ),
                  child: Row(
                    children: [
                      PersonAvatar(participant: people[i]),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (people[i]['name'] ?? '').toString(),
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: p.textPrimary,
                              ),
                            ),
                            if (subtitleFor(people[i]).isNotEmpty)
                              Text(
                                subtitleFor(people[i]),
                                style: AppTypography.caption.copyWith(
                                  color: p.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      AssignCheckbox(checked: isSelected(people[i])),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
