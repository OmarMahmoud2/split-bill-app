import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

class EditAssignmentSheet extends StatefulWidget {
  final List<Map<String, dynamic>> participants;
  final List<String> currentSelection;
  final Function(List<String>) onConfirm;

  const EditAssignmentSheet({
    super.key,
    required this.participants,
    required this.currentSelection,
    required this.onConfirm,
  });

  @override
  State<EditAssignmentSheet> createState() => _EditAssignmentSheetState();

  static void show(
    BuildContext context, {
    required List<Map<String, dynamic>> participants,
    required List<String> currentSelection,
    required Function(List<String>) onConfirm,
  }) {
    PremiumBottomSheet.show(
      context: context,
      isScrollable: true,
      child: EditAssignmentSheet(
        participants: participants,
        currentSelection: currentSelection,
        onConfirm: onConfirm,
      ),
    );
  }
}

class _EditAssignmentSheetState extends State<EditAssignmentSheet> {
  late List<String> _tempSelection;

  @override
  void initState() {
    super.initState();
    _tempSelection = List.from(widget.currentSelection);
  }

  ImageProvider? _getAvatarImage(String? url) {
    return ImageUtils.getAvatarImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'who_split_this_item',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ).tr(),
        const SizedBox(height: 8),
        Text(
          'select_people_who_shared_this_item_to_calculate_the_split',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ).tr(),
        const SizedBox(height: 20),
        
        ...widget.participants.map((p) {
          final isSelected = _tempSelection.contains(p['id']);
          final avatarColor = p['color'] as Color? ?? colorScheme.primary;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _tempSelection.remove(p['id']);
                    } else {
                      _tempSelection.add(p['id']);
                    }
                  });
                  HapticFeedback.selectionClick();
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? avatarColor.withValues(alpha: 0.08)
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? avatarColor.withValues(alpha: 0.4)
                          : colorScheme.outline.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? avatarColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundImage: _getAvatarImage(p['photoUrl']),
                          backgroundColor: avatarColor.withValues(alpha: 0.2),
                          child: _getAvatarImage(p['photoUrl']) == null
                              ? Text(
                                  p['name'][0].toUpperCase(),
                                  style: TextStyle(
                                    color: avatarColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          p['name'],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? avatarColor : colorScheme.onSurface,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: avatarColor,
                                key: const ValueKey('selected'),
                              )
                            : Icon(
                                Icons.circle_outlined,
                                color: colorScheme.outline.withValues(alpha: 0.3),
                                key: const ValueKey('unselected'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        
        const SizedBox(height: 24),
        
        // Confirm Button
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(_tempSelection);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            minimumSize: const Size(double.infinity, 58),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            'confirm_selection',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onPrimary,
            ),
          ).tr(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
