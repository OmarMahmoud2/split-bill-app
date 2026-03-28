import 'package:flutter/material.dart';
import 'widgets/guest_header.dart';
import 'widgets/orbiting_avatars.dart';

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
    return Center(
      key: const ValueKey('SelectorView'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Header
            GuestHeader(storeName: storeName, isCompact: false),

            const SizedBox(height: 60),

            // Orbiting Avatars
            SizedBox(
              height: 380,
              width: 380,
              child: OrbitingAvatars(
                participants: participants,
                onSelect: onParticipantSelected,
              ),
            ),
            const SizedBox(height: 40),

            // Instructions
            Text(
              "Tap your avatar to log in",
              style: TextStyle(
                color: Colors.blueGrey[400],
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
