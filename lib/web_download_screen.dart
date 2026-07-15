import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:split_bill_app/config/app_links.dart';

class WebDownloadScreen extends StatelessWidget {
  const WebDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 820;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 24 : 48,
              vertical: isCompact ? 28 : 44,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: isCompact
                  ? Column(
                      children: [
                        _DownloadCopy(isCompact: isCompact),
                        const SizedBox(height: 40),
                        _PhonePreview(isCompact: isCompact),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _DownloadCopy(isCompact: isCompact),
                        ),
                        const SizedBox(width: 56),
                        const Expanded(
                          flex: 5,
                          child: _PhonePreview(isCompact: false),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadCopy extends StatelessWidget {
  const _DownloadCopy({required this.isCompact});

  final bool isCompact;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: isCompact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/logo.png',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Split Bill',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 34),
        Text(
          'web_download_headline'.tr(),
          textAlign: isCompact ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.05,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'web_download_body'.tr(),
          textAlign: isCompact ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF526070),
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: isCompact ? WrapAlignment.center : WrapAlignment.start,
          children: [
            _StoreButton(
              icon: Icons.apple,
              label: 'web_download_app_store'.tr(),
              onTap: () => _openUrl(AppLinks.appStoreUrl),
            ),
            _StoreButton(
              icon: Icons.android_rounded,
              label: 'web_download_play_store'.tr(),
              onTap: () => _openUrl(AppLinks.playStoreUrl),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Text(
          'web_download_guest_note'.tr(),
          textAlign: isCompact ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF667085),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _StoreButton extends StatelessWidget {
  const _StoreButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final maxWidth = (MediaQuery.sizeOf(context).width - 48)
        .clamp(232.0, 360.0)
        .toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 232, maxWidth: maxWidth),
      child: Material(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: isCompact ? 260 : 330,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Image.asset(
            'assets/onboarding/onboarding_scan_receipt_1767296144198-removebg-preview.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
