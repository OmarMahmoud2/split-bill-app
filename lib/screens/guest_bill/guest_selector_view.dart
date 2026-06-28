import 'package:flutter/material.dart';
import 'widgets/guest_header.dart';
import 'package:easy_localization/easy_localization.dart';

class GuestSelectorView extends StatelessWidget {
  final List<dynamic> participants;
  final String storeName;
  final Function(String) onParticipantSelected;

  const GuestSelectorView({
    super.key,
    required this.participants,
    required this.storeName,
    required this.onParticipantSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      key: const ValueKey('SelectorView'),
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 700;
        final horizontalPadding = isTablet ? 32.0 : 16.0;
        final contentWidth = isTablet
            ? 680.0
            : (constraints.maxWidth - (horizontalPadding * 2))
                  .clamp(0.0, 680.0)
                  .toDouble();

        return SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isTablet ? 32 : 16,
                horizontalPadding,
                32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Column(
                  children: [
                    GuestHeader(storeName: storeName, isCompact: false),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'select_nyour_name',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ).tr(),
                          const SizedBox(height: 6),
                          Text(
                            'tap_your_avatar_to_log_in',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.62,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ).tr(),
                          const SizedBox(height: 18),
                          if (participants.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 28,
                                ),
                                child: Text(
                                  'add_participants_first',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ).tr(),
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, tileConstraints) {
                                final tileWidth = isTablet
                                    ? (tileConstraints.maxWidth - 12) / 2
                                    : tileConstraints.maxWidth;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    for (
                                      int i = 0;
                                      i < participants.length;
                                      i++
                                    )
                                      SizedBox(
                                        width: tileWidth,
                                        child: _GuestParticipantTile(
                                          participant: participants[i],
                                          index: i,
                                          onTap: () => onParticipantSelected(
                                            participants[i]['id'].toString(),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GuestParticipantTile extends StatelessWidget {
  final dynamic participant;
  final int index;
  final VoidCallback onTap;

  const _GuestParticipantTile({
    required this.participant,
    required this.index,
    required this.onTap,
  });

  static const _avatarColors = [
    Color(0xFF00ACC1),
    Color(0xFFFF7043),
    Color(0xFF26A69A),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
    Color(0xFFFFCA28),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = (participant['name'] ?? 'guest'.tr()).toString();
    final trimmedName = name.trim();
    final color = _avatarColors[index % _avatarColors.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Text(
                  trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : '?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
