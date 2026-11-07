import 'package:flutter/material.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';

/// The user's pal, or their photo (URL or base64).
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
  Widget build(BuildContext context) => PalAvatar(
    seed: name.trim().toLowerCase(),
    name: name,
    photoUrl: photoUrl,
    size: size,
  );
}
