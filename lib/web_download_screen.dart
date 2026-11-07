import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';

import 'screens/guest_bill/widgets/guest_chrome.dart';

/// The web root without a bill link: send people to the stores. One centred
/// column (max 480) on every width, light and dark.
class WebDownloadScreen extends StatelessWidget {
  const WebDownloadScreen({super.key});

  static const _pals = ['mona', 'omar', 'sara', 'ali', 'nour'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const size = 64.0;
    const step = 44.0;
    final cluster = ExcludeSemantics(
      child: SizedBox(
        width: step * (_pals.length - 1) + size,
        height: size,
        child: Stack(
          children: [
            for (var i = 0; i < _pals.length; i++)
              PositionedDirectional(
                start: i * step,
                child: PalAvatar(
                  seed: _pals[i],
                  size: size,
                  ringColor: p.background,
                ),
              ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: p.background,
      body: AdaptiveBody.form(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        GuestBrand(large: true),
                        Spacer(),
                        GuestLanguageButton(),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Center(child: cluster),
                    const SizedBox(height: 32),
                    Semantics(
                      header: true,
                      child: Text(
                        'web_download_headline'.tr(),
                        style: AppTypography.displaySmall.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'web_download_body'.tr(),
                      style: AppTypography.bodyLarge.copyWith(
                        fontSize: 16,
                        height: 1.5,
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const GuestStoreButtons(),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: AppRadii.cardRadius,
                        border: Border.all(color: p.border),
                        boxShadow: p.softShadow,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(AppIcons.receipt, size: 22, color: p.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'web_download_guest_note'.tr(),
                              style: AppTypography.bodyMedium.copyWith(
                                height: 1.5,
                                color: p.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
