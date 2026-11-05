import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/image_utils.dart';

/// Initial on a stable tint, or the user's photo (URL or base64).
class AdminAvatar extends StatelessWidget {
  const AdminAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 40,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final image = ImageUtils.getAvatarImage(photoUrl);
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: p.avatarTintFor(name),
        foregroundImage: image,
        child: Text(
          initial,
          style: AppTypography.titleMedium.copyWith(
            color: p.textPrimary,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}
