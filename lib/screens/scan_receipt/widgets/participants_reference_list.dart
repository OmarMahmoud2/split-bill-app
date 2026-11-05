import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/utils/image_utils.dart';

class ParticipantsReferenceList extends StatelessWidget {
  final List<Map<String, dynamic>>? participants;

  const ParticipantsReferenceList({super.key, required this.participants});

  ImageProvider? _getAvatarImage(String? url) {
    return ImageUtils.getAvatarImage(url);
  }

  @override
  Widget build(BuildContext context) {
    if (participants == null || participants!.isEmpty) {
      return const SizedBox.shrink();
    }
    final palette = context.palette;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.record_voice_over_rounded,
                size: 16,
                color: palette.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'voice_reference',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: palette.textSecondary,
                  letterSpacing: 0.5,
                ),
              ).tr(),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 85,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: participants!.length,
              separatorBuilder: (c, i) => const SizedBox(width: 20),
              itemBuilder: (context, index) {
                final p = participants![index];
                final data = p.containsKey('data')
                    ? (p['data'] as Map<String, dynamic>)
                    : p;
                final name =
                    data['displayName'] ?? data['name'] ?? context.tr('guest');
                final photoUrl = data['photoUrl'];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: palette.borderSubtle,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: palette.surfaceVariant,
                        backgroundImage: _getAvatarImage(photoUrl),
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(
                                name[0].toUpperCase(),
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
