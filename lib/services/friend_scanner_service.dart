import 'package:split_bill_app/services/my_photo.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/qr_dialog.dart';

/// What a scanned QR turned out to be.
enum FriendCodeKind { friend, self, invalid }

class FriendCode {
  const FriendCode(this.kind, [this.uid]);

  final FriendCodeKind kind;

  /// The friend's user id when [kind] is [FriendCodeKind.friend] or
  /// [FriendCodeKind.self].
  final String? uid;
}

final RegExp _uidPattern = RegExp(r'^[A-Za-z0-9_-]{6,128}$');

/// Reads a Split Bill friend code: the raw user id ("Your code" encodes the
/// uid), or a link carrying it as `uid` / `u`. Anything else is invalid.
FriendCode parseFriendCode(String? raw, {String? selfUid}) {
  var value = (raw ?? '').trim();
  if (value.isEmpty) return const FriendCode(FriendCodeKind.invalid);
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    value = uri.queryParameters['uid'] ?? uri.queryParameters['u'] ?? '';
  }
  if (!_uidPattern.hasMatch(value)) {
    return const FriendCode(FriendCodeKind.invalid);
  }
  if (selfUid != null && value == selfUid) {
    return FriendCode(FriendCodeKind.self, value);
  }
  return FriendCode(FriendCodeKind.friend, value);
}

/// "Add a friend by QR, both ways" (People board 2): a dark camera with a
/// teal frame, and the user's own code below for the other direction.
/// Pops the scanned friend's uid, or null.
class ScanFriendScreen extends StatefulWidget {
  const ScanFriendScreen({super.key, this.myUid, this.myName, this.myPhotoUrl});

  /// The current user's code; defaults to the signed-in user.
  final String? myUid;
  final String? myName;
  final String? myPhotoUrl;

  @override
  State<ScanFriendScreen> createState() => _ScanFriendScreenState();
}

class _ScanFriendScreenState extends State<ScanFriendScreen> {
  late final MobileScannerController controller;
  bool _hasScanned = false;
  DateTime? _cooldownUntil;
  String? _myUid;
  String? _myName;
  String? _myPhotoUrl;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    _myUid = widget.myUid;
    _myName = widget.myName;
    _myPhotoUrl = widget.myPhotoUrl;
    if (_myUid == null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        _myUid = user?.uid;
        _myName ??= user?.displayName;
        _myPhotoUrl ??= MyPhoto.notifier.value;
      } catch (_) {
        // Firebase not ready: the "Your code" card is hidden.
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final now = DateTime.now();
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final code = parseFriendCode(raw, selfUid: _myUid);
      switch (code.kind) {
        case FriendCodeKind.friend:
          setState(() => _hasScanned = true);
          AppHaptics.success();
          Navigator.pop(context, code.uid);
          return;
        case FriendCodeKind.self:
          _cooldownUntil = now.add(const Duration(seconds: 2));
          AppHaptics.warning();
          AppToast.show(
            context,
            message: 'bf_assign_scan_own_code'.tr(),
            type: AppToastType.info,
            position: AppToastPosition.top,
          );
          return;
        case FriendCodeKind.invalid:
          _cooldownUntil = now.add(const Duration(seconds: 2));
          AppHaptics.error();
          AppToast.show(
            context,
            message: 'bf_assign_scan_invalid'.tr(),
            type: AppToastType.error,
            position: AppToastPosition.top,
          );
          return;
      }
    }
  }

  Widget _error(BuildContext context, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: AppPalette.dark.background,
      child: Theme(
        data: AppTheme.darkTheme,
        child: ErrorState(
          icon: denied ? AppIcons.cameraOff : AppIcons.videoOff,
          title: denied
              ? 'bf_assign_camera_denied_title'.tr()
              : 'bf_assign_camera_error_title'.tr(),
          message: denied
              ? 'bf_assign_camera_denied_message'.tr()
              : 'bf_assign_camera_error_message'.tr(),
          onRetry: () => controller.start(),
          secondaryLabel: 'close'.tr(),
          onSecondary: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const p = AppPalette.dark;
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: p.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              errorBuilder: _error,
              placeholderBuilder: (_) => ColoredBox(color: p.background),
            ),
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, _) => state.error != null
                  ? const SizedBox.shrink()
                  : _overlay(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    const p = AppPalette.dark;
    const card = AppPalette.light;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Material(
                color: p.textPrimary.withValues(alpha: 0.12),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'close'.tr(),
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(AppIcons.close, color: p.textPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 60),
          IgnorePointer(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(28)),
                border: Border.all(color: p.accent, width: 3),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'bf_assign_scan_point'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
          const Spacer(),
          if (_myUid != null && _myUid!.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
              child: Material(
                color: card.surface,
                borderRadius: AppRadii.cardRadius,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => QrDialog.show(
                    context,
                    _myName ?? '',
                    _myPhotoUrl,
                    _myUid!,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: QrImageView(
                            data: _myUid!,
                            size: 72,
                            padding: EdgeInsets.zero,
                            backgroundColor: card.surface,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: card.textPrimary,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: card.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'bf_assign_your_code'.tr(),
                                style: AppTypography.titleMedium.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: card.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'bf_assign_your_code_hint'.tr(),
                                style: AppTypography.caption.copyWith(
                                  color: card.textSecondary,
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
        ],
      ),
    );
  }
}
