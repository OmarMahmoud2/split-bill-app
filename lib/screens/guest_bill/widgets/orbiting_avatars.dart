import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/theme/app_palette.dart';

class OrbitingAvatars extends StatefulWidget {
  final List<dynamic> participants;
  final Function(String) onSelect;

  const OrbitingAvatars({
    super.key,
    required this.participants,
    required this.onSelect,
  });

  @override
  State<OrbitingAvatars> createState() => _OrbitingAvatarsState();
}

class _OrbitingAvatarsState extends State<OrbitingAvatars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40), // Slower orbit for elegance
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight / 2,
        );
        // Radius: adjust so avatars float around but stay visible
        final radiusX = constraints.maxWidth * 0.35;
        final radiusY = constraints.maxHeight * 0.35;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Center Piece (Logo/Text)
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.surface,
                boxShadow: [
                  BoxShadow(
                    color: p.info.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/animations/split_bill.json',
                    width: 70,
                    height: 70,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.infoAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'select_nyour_name',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                      height: 1.2,
                    ),
                  ).tr(),
                ],
              ),
            ),

            // Orbiting Avatars
            ...List.generate(widget.participants.length, (index) {
              final participant = widget.participants[index];
              final count = widget.participants.length;
              final angleStep = (2 * math.pi) / count;

              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final currentAngle =
                      (_controller.value * 2 * math.pi) + (index * angleStep);

                  final x = center.dx + math.cos(currentAngle) * radiusX - 35;
                  final y = center.dy + math.sin(currentAngle) * radiusY - 35;

                  return Positioned(left: x, top: y, child: child!);
                },
                child: _buildAvatar(participant),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildAvatar(dynamic participant) {
    final String name = participant['name'] ?? "Guest";
    final p = context.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onSelect(participant['id']),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 85,
          height: 85,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: p.tint(Colors.blue.shade100, p.info, darkAlpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: p.shadow.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.infoSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "?",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: p.infoStrong,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
