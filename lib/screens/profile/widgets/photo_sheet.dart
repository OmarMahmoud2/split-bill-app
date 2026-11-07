import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

enum PhotoChoice { camera, library, provider, remove }

/// What the user picked: a cropped local [file], or [removed].
class PhotoResult {
  const PhotoResult.file(File this.file) : removed = false;
  const PhotoResult.removed() : file = null, removed = true;

  final File? file;
  final bool removed;
}

/// The signed-in user's Google/Apple photo URL, or null.
String? providerPhotoUrl(User? user) {
  final url = user?.photoURL;
  return (url == null || url.isEmpty) ? null : url;
}

bool _isApple(User? user) =>
    user?.providerData.any((p) => p.providerId == 'apple.com') ?? false;

/// Bottom sheet with the photo choices. The Google/Apple option is shown
/// only when [providerUrl] is non-null, with that photo as a preview.
Future<PhotoChoice?> showPhotoSheet(
  BuildContext context, {
  String? providerUrl,
  bool providerIsApple = false,
  bool hasPhoto = false,
}) {
  return showLedgerSheet<PhotoChoice>(
    context,
    title: 'you_photo_title'.tr(),
    builder: (sheetContext) {
      final p = sheetContext.palette;
      Widget row(
        Key key,
        IconData icon,
        String label,
        PhotoChoice choice, {
        Widget? leading,
        bool destructive = false,
      }) => SettingsRow(
        key: key,
        title: label,
        destructive: destructive,
        showChevron: false,
        leading:
            leading ??
            SettingsIconTile(
              icon,
              tint: destructive ? p.errorSoft : p.accentSoft,
              ink: destructive ? p.error : p.accent,
            ),
        onTap: () => Navigator.of(sheetContext).pop(choice),
      );
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 20),
        child: SettingsCard(
          children: [
            row(
              const ValueKey('photo-take'),
              AppIcons.camera,
              'you_photo_take'.tr(),
              PhotoChoice.camera,
            ),
            row(
              const ValueKey('photo-library'),
              AppIcons.gallery,
              'you_photo_library'.tr(),
              PhotoChoice.library,
            ),
            if (providerUrl != null)
              row(
                const ValueKey('photo-provider'),
                AppIcons.you,
                (providerIsApple ? 'you_photo_apple' : 'you_photo_google').tr(),
                PhotoChoice.provider,
                leading: ClipOval(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Image(
                      image:
                          ImageUtils.getAvatarImage(providerUrl) ??
                          const AssetImage(
                            'assets/brand/evens_splash_light.png',
                          ),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            if (hasPhoto)
              row(
                const ValueKey('photo-remove'),
                AppIcons.delete,
                'you_photo_remove'.tr(),
                PhotoChoice.remove,
                destructive: true,
              ),
          ],
        ),
      );
    },
  );
}

/// Full flow: sheet, pick, square crop, resize to <= 512 px JPEG at 80%.
/// Returns null when cancelled or when picking failed (see [failed]).
Future<PhotoResult?> choosePhoto(
  BuildContext context, {
  required bool hasPhoto,
  required void Function() failed,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  final url = providerPhotoUrl(user);
  final choice = await showPhotoSheet(
    context,
    providerUrl: url,
    providerIsApple: _isApple(user),
    hasPhoto: hasPhoto,
  );
  if (choice == null) return null;
  if (choice == PhotoChoice.remove) return const PhotoResult.removed();
  if (!context.mounted) return null;
  final p = context.palette;
  final title = 'prof_change_photo'.tr();
  try {
    String? source;
    if (choice == PhotoChoice.provider) {
      final res = await http.get(Uri.parse(url!));
      if (res.statusCode != 200) throw Exception('photo ${res.statusCode}');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/provider_photo.jpg');
      await file.writeAsBytes(res.bodyBytes);
      source = file.path;
    } else {
      // Pre-shrunk by the picker so the cropper stays light on memory.
      final img = await ImagePicker().pickImage(
        source: choice == PhotoChoice.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        preferredCameraDevice: CameraDevice.front,
      );
      source = img?.path;
    }
    if (source == null) return null;
    final cropped = await ImageCropper().cropImage(
      sourcePath: source,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 512,
      maxHeight: 512,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: p.inverseSurface,
          toolbarWidgetColor: p.onInverseSurface,
          activeControlsWidgetColor: p.accent,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: title,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    return cropped == null ? null : PhotoResult.file(File(cropped.path));
  } catch (_) {
    failed();
    return null;
  }
}
