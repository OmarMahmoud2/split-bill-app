import 'package:flutter/material.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:split_bill_app/edit_profile_screen.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String? phoneNumber;
  final Map<String, dynamic> userData;

  const ProfileHeader({
    super.key,
    required this.name,
    this.photoUrl,
    this.phoneNumber,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 65, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(18),
                image: ImageUtils.getAvatarImage(photoUrl) != null
                    ? DecorationImage(
                        image: ImageUtils.getAvatarImage(photoUrl)!,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: ImageUtils.getAvatarImage(photoUrl) == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: Colors.grey,
                      size: 30,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Name & Phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phoneNumber ?? "No phone set",
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
            // Edit Button
            Material(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(currentData: userData),
                  ),
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.edit_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
