import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/money_text.dart';

// ============================================================ pure list logic

/// Status chip filter of the bills list.
enum BillStatusFilter { all, open, settled }

/// What the user typed and toggled on the bills list.
class BillListQuery {
  const BillListQuery({
    this.text = '',
    this.status = BillStatusFilter.all,
    this.mineOnly = false,
    this.month,
  });

  final String text;
  final BillStatusFilter status;

  /// Only bills the current user paid for (hosted).
  final bool mineOnly;

  /// Only bills in this year + month (day ignored).
  final DateTime? month;

  bool get hasFilters =>
      text.trim().isNotEmpty ||
      status != BillStatusFilter.all ||
      mineOnly ||
      month != null;

  BillListQuery copyWith({
    String? text,
    BillStatusFilter? status,
    bool? mineOnly,
    DateTime? month,
    bool clearMonth = false,
  }) => BillListQuery(
    text: text ?? this.text,
    status: status ?? this.status,
    mineOnly: mineOnly ?? this.mineOnly,
    month: clearMonth ? null : (month ?? this.month),
  );
}

const Map<String, String> _latinFolds = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a', 'æ': 'ae', 'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd',
  'đ': 'd', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ę': 'e',
  'ě': 'e', 'ğ': 'g', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ı': 'i', 'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n', 'ò': 'o', 'ó': 'o',
  'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o', 'œ': 'oe',
  'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's', 'ß': 'ss', 'ť': 't', 'ţ': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
  'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z', 'ơ': 'o', 'ư': 'u',
  'ạ': 'a', 'ả': 'a', 'ấ': 'a', 'ầ': 'a', 'ậ': 'a', 'ắ': 'a', 'ặ': 'a',
  'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ế': 'e', 'ề': 'e', 'ệ': 'e', 'ị': 'i',
  'ọ': 'o', 'ỏ': 'o', 'ố': 'o', 'ồ': 'o', 'ộ': 'o', 'ớ': 'o', 'ờ': 'o',
  'ợ': 'o', 'ụ': 'u', 'ủ': 'u', 'ứ': 'u', 'ừ': 'u', 'ự': 'u', 'ỳ': 'y',
  // Arabic letter variants.
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ى': 'ي', 'ة': 'ه', 'ؤ': 'و',
  'ئ': 'ي',
};

final RegExp _marks = RegExp('[̀-ًͯ-ٰٟـ]');
final RegExp _spaces = RegExp(r'\s+');

/// Lower-cases and strips accents / Arabic diacritics so "cafe" finds
/// "Café" and "محمد" finds "مُحَمَّد".
String normalizeForSearch(String input) {
  final lower = input.toLowerCase().replaceAll(_marks, '');
  final out = StringBuffer();
  for (final ch in lower.characters) {
    out.write(_latinFolds[ch] ?? ch);
  }
  return out.toString().replaceAll(_spaces, ' ').trim();
}

/// Whether [data] counts as settled for [uid]: the host when nobody is
/// pending or in review, a participant when their own share is paid.
bool isBillSettledFor(Map<String, dynamic> data, String uid) {
  final parts = BillReader(data).participants;
  if (data['hostId'] == uid) {
    return !parts.any(
      (p) => p['status'] == 'PENDING' || p['status'] == 'REVIEW',
    );
  }
  for (final p in parts) {
    if (p['id']?.toString() == uid) return p['status'] == 'PAID';
  }
  return false;
}

/// One row of the bills list, from the current user's perspective.
class BillListEntry {
  const BillListEntry({
    required this.id,
    required this.name,
    required this.date,
    required this.currency,
    required this.amountMinor,
    required this.settled,
    required this.isMine,
    required this.peopleCount,
    required this.searchKey,
    this.groupName,
    this.payerName,
    this.data = const {},
  });

  /// Builds the row for [uid]. The amount is signed: + what the others
  /// owe the host (still unpaid while open, their whole shares once
  /// settled), − the participant's own share.
  factory BillListEntry.fromData(
    String id,
    Map<String, dynamic> data,
    String uid,
  ) {
    final reader = BillReader(data);
    final parts = reader.participants;
    final isMine = data['hostId'] == uid;
    final settled = isBillSettledFor(data, uid);
    int amount;
    if (isMine) {
      amount = 0;
      for (final p in parts) {
        if (p['id']?.toString() == uid) continue;
        amount += settled
            ? reader.shareMinorOf(p)
            : reader.outstandingMinorOf(p);
      }
    } else {
      final me = reader.participant(uid);
      amount = me == null
          ? 0
          : -(settled
                ? reader.shareMinorOf(me)
                : reader.outstandingMinorOf(me));
    }
    final raw = data['date'];
    final date = raw is Timestamp
        ? raw.toDate()
        : raw is DateTime
        ? raw
        : DateTime.fromMillisecondsSinceEpoch(0);
    String? payer;
    if (!isMine) {
      final host = reader.participant(data['hostId']?.toString() ?? '');
      final n = host?['name']?.toString().trim();
      payer = (n == null || n.isEmpty) ? null : n;
    }
    final group = data['groupName']?.toString().trim();
    final name = (data['storeName'] ?? '').toString();
    final haystack = [
      name,
      ?group,
      for (final p in parts) (p['name'] ?? '').toString(),
      for (final i in reader.items) (i['name'] ?? '').toString(),
    ].join('\n');
    return BillListEntry(
      id: id,
      name: name,
      date: date,
      currency: reader.currency,
      amountMinor: amount,
      settled: settled,
      isMine: isMine,
      peopleCount: parts.length,
      groupName: (group == null || group.isEmpty) ? null : group,
      payerName: payer,
      searchKey: normalizeForSearch(haystack),
      data: data,
    );
  }

  final String id;
  final String name;
  final DateTime date;
  final String currency;

  /// Signed minor units: + owed to you, − you owe.
  final int amountMinor;
  final bool settled;

  /// The current user hosted (paid) this bill.
  final bool isMine;
  final int peopleCount;
  final String? groupName;

  /// Who paid, for bills the current user did not host.
  final String? payerName;

  /// [normalizeForSearch] of name, group, people and items.
  final String searchKey;
  final Map<String, dynamic> data;

  bool matches(BillListQuery q) {
    if (q.status == BillStatusFilter.open && settled) return false;
    if (q.status == BillStatusFilter.settled && !settled) return false;
    if (q.mineOnly && !isMine) return false;
    final m = q.month;
    if (m != null && (date.year != m.year || date.month != m.month)) {
      return false;
    }
    final text = normalizeForSearch(q.text);
    if (text.isEmpty) return true;
    return text.split(' ').every(searchKey.contains);
  }
}

enum BillSectionKind { thisWeek, month }

class BillListSection {
  const BillListSection({
    required this.kind,
    required this.entries,
    this.month,
  });

  final BillSectionKind kind;

  /// First day of the month for [BillSectionKind.month].
  final DateTime? month;
  final List<BillListEntry> entries;
}

/// Monday 00:00 of the week containing [now] (local time).
DateTime startOfWeek(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Filters [entries] with [query], newest first, then groups them: THIS
/// WEEK (since Monday, including future-dated bills) and one section per
/// earlier month.
List<BillListSection> filterAndGroupBills(
  List<BillListEntry> entries,
  BillListQuery query,
  DateTime now,
) {
  final matching = entries.where((e) => e.matches(query)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final weekStart = startOfWeek(now);
  final sections = <BillListSection>[];
  final thisWeek = <BillListEntry>[];
  final byMonth = <DateTime, List<BillListEntry>>{};
  for (final e in matching) {
    if (!e.date.isBefore(weekStart)) {
      thisWeek.add(e);
    } else {
      byMonth.putIfAbsent(DateTime(e.date.year, e.date.month), () => []).add(e);
    }
  }
  if (thisWeek.isNotEmpty) {
    sections.add(
      BillListSection(kind: BillSectionKind.thisWeek, entries: thisWeek),
    );
  }
  for (final e in byMonth.entries) {
    sections.add(
      BillListSection(
        kind: BillSectionKind.month,
        month: e.key,
        entries: e.value,
      ),
    );
  }
  return sections;
}

String? _dateLocale(BuildContext context) {
  final tag = Localizations.maybeLocaleOf(context)?.toLanguageTag();
  if (tag == null) return null;
  try {
    if (DateFormat.localeExists(tag)) return tag;
    final lang = tag.split(RegExp('[-_]')).first;
    return DateFormat.localeExists(lang) ? lang : null;
  } catch (_) {
    return null;
  }
}

// ======================================================== presentational UI

/// The MON / day tile at the start of a bill row.
class BillDateTile extends StatelessWidget {
  const BillDateTile({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final locale = _dateLocale(context);
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: p.surfaceVariant,
          borderRadius: AppRadii.rowRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat.MMM(locale).format(date).toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                fontSize: 10,
                height: 1.1,
                color: p.textSecondary,
              ),
              maxLines: 1,
            ),
            Text(
              '${date.day}',
              style: AppTypography.labelSmall.copyWith(
                fontSize: 12,
                height: 1.1,
                color: p.textPrimary,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bill: date tile, name, "group · 4 people" / "Ali paid", and the
/// signed amount (+ teal owed to you, − amber you owe; ink once settled).
class BillListRow extends StatelessWidget {
  const BillListRow({super.key, required this.entry, this.onTap});

  final BillListEntry entry;
  final VoidCallback? onTap;

  String _subtitle() {
    final parts = <String>[
      ?entry.groupName,
      if (entry.isMine)
        'bf_bills_people'.tr(namedArgs: {'count': '${entry.peopleCount}'})
      else if (entry.payerName != null)
        'bf_bills_paid_by'.tr(namedArgs: {'name': entry.payerName!}),
      if (entry.settled) 'bf_bills_settled_tag'.tr(),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final amountText = formatMoneyMinor(
      entry.amountMinor.abs(),
      entry.currency,
    );
    final amountLabel = entry.amountMinor > 0
        ? 'bf_bills_semantics_owed'.tr(namedArgs: {'amount': amountText})
        : entry.amountMinor < 0
        ? 'bf_bills_semantics_owe'.tr(namedArgs: {'amount': amountText})
        : amountText;
    final name = entry.name.trim().isEmpty
        ? 'bf_bills_untitled'.tr()
        : entry.name;
    return Semantics(
      button: onTap != null,
      label:
          '$name, ${DateFormat.yMMMd(_dateLocale(context)).format(entry.date)}, '
          '${_subtitle()}, $amountLabel',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                BillDateTile(date: entry.date),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        _subtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                MoneyText(
                  minor: entry.amountMinor,
                  currency: entry.currency,
                  sign: MoneySign.always,
                  tone: entry.settled ? MoneyTone.neutral : MoneyTone.auto,
                  semanticsLabel: amountLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section label + a hairline card of rows.
class BillListSectionView extends StatelessWidget {
  const BillListSectionView({
    super.key,
    required this.section,
    required this.onTap,
  });

  final BillListSection section;
  final ValueChanged<BillListEntry> onTap;

  String _title(BuildContext context) {
    if (section.kind == BillSectionKind.thisWeek) {
      return 'bf_bills_this_week'.tr().toUpperCase();
    }
    final m = section.month!;
    final locale = _dateLocale(context);
    final label = m.year == DateTime.now().year
        ? DateFormat.MMMM(locale).format(m)
        : DateFormat.yMMMM(locale).format(m);
    return label.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 18, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              _title(context),
              style: AppTypography.titleSmall.copyWith(color: p.textSecondary),
            ),
          ),
        ),
        Material(
          color: p.surface,
          shape: AppRadii.cardShape(p.border),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < section.entries.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: p.borderSubtle),
                BillListRow(
                  entry: section.entries[i],
                  onTap: () => onTap(section.entries[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A v3 filter chip: ink when selected, hairline outline otherwise.
class BillFilterChip extends StatelessWidget {
  const BillFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.inverseSurface : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.chipRadius,
          side: BorderSide(color: selected ? p.inverseSurface : p.borderStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: selected ? p.onInverseSurface : p.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
