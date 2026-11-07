import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/app_text_field.dart';
import 'package:split_bill_app/widgets/motion/motion.dart';

class SearchableSheetItem<T> {
  const SearchableSheetItem({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.leading,
    this.searchTerms = const [],
  });

  final T value;
  final String title;
  final String subtitle;
  final Widget leading;
  final List<String> searchTerms;
}

class SearchableSelectionSheet<T> extends StatefulWidget {
  const SearchableSelectionSheet({
    super.key,
    required this.title,
    required this.searchHint,
    required this.items,
    required this.isSelected,
    required this.onSelected,
    this.emptyTitle = 'No matches found',
    this.emptyMessage = 'Try another search term.',
  });

  final String title;
  final String searchHint;
  final List<SearchableSheetItem<T>> items;
  final bool Function(T value) isSelected;
  final ValueChanged<T> onSelected;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<SearchableSelectionSheet<T>> createState() =>
      _SearchableSelectionSheetState<T>();
}

class _SearchableSelectionSheetState<T>
    extends State<SearchableSelectionSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final filteredItems = widget.items.where((item) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      final haystack = [
        item.title,
        item.subtitle,
        ...item.searchTerms,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: AppTypography.headlineSmall.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _searchController,
                hint: widget.searchHint,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                prefix: Icon(AppIcons.search, color: p.accent, size: 20),
                suffix: _query.isEmpty
                    ? null
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        child: Tooltip(
                          message: 'bf_bills_clear_search'.tr(),
                          child: Icon(
                            AppIcons.cancel,
                            size: 20,
                            color: p.textTertiary,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),

        // List
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: filteredItems.isEmpty
              ? _buildEmptyState(context)
              : ListView.separated(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 24),
                  itemCount: filteredItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final selected = widget.isSelected(item.value);

                    return _buildItemTile(context, item, selected);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildItemTile(
    BuildContext context,
    SearchableSheetItem<T> item,
    bool selected,
  ) {
    final p = context.palette;
    return Pressable(
      onTap: () => widget.onSelected(item.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
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
            item.leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? p.onAccentSoft : p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selected)
              Icon(AppIcons.successFill, color: p.accent)
            else
              Icon(AppIcons.chevronRight, size: 14, color: p.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: p.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(AppIcons.search, size: 32, color: p.textSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              widget.emptyTitle,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
