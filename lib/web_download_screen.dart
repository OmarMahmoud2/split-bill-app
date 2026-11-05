import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:split_bill_app/theme/theme.dart';

import 'screens/guest_bill/widgets/guest_chrome.dart';

/// The web root without a bill link: send people to the stores (v3 style).
class WebDownloadScreen extends StatelessWidget {
  const WebDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'web_download_headline'.tr(),
            style:
                (desktop
                        ? AppTypography.displayLarge
                        : AppTypography.displaySmall)
                    .copyWith(color: p.textPrimary),
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 20),
        Text(
          'web_download_guest_note'.tr(),
          style: AppTypography.bodyMedium.copyWith(
            height: 1.5,
            color: p.textSecondary,
          ),
        ),
      ],
    );

    final preview = ExcludeSemantics(
      child: Container(
        constraints: BoxConstraints(maxWidth: desktop ? 340 : 260),
        decoration: BoxDecoration(
          color: p.surfaceVariant,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: p.border),
        ),
        padding: const EdgeInsets.all(20),
        child: Image.asset(
          'assets/onboarding/onboarding_scan_receipt_1767296144198-removebg-preview.png',
          fit: BoxFit.contain,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: desktop ? p.surface : p.background,
                border: desktop
                    ? Border(bottom: BorderSide(color: p.border))
                    : null,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop ? 24 : 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        GuestBrand(large: desktop),
                        const Spacer(),
                        const GuestLanguageButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: desktop ? 24 : 20,
                  vertical: desktop ? 56 : 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: desktop
                        ? Row(
                            children: [
                              Expanded(flex: 6, child: copy),
                              const SizedBox(width: 56),
                              Expanded(flex: 5, child: Center(child: preview)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              copy,
                              const SizedBox(height: 36),
                              Center(child: preview),
                            ],
                          ),
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
