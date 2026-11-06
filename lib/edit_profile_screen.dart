import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:split_bill_app/services/profile_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

/// Strips spaces, dashes and brackets; returns null unless the result is a
/// plausible E.164 number ("+201012345678"). Empty input returns "".
String? normalizeOptionalPhone(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  if (cleaned.isEmpty) return '';
  return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(cleaned) ? cleaned : null;
}

/// v3 Edit profile: photo, name shown to friends, read-only email and an
/// optional phone number.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.currentData});

  final Map<String, dynamic> currentData;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  File? _newImage;
  bool _saving = false;
  String? _nameError;
  String? _phoneError;

  final ProfileService _profileService = ProfileService();
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentData['displayName'] ?? _user?.displayName ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.currentData['phoneNumber'] ?? _user?.phoneNumber ?? '',
    );
    _emailController = TextEditingController(
      text:
          (widget.currentData['email'] as String?) ??
          _user?.email ??
          'no_email_linked'.tr(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 25,
        maxWidth: 400,
      );
      if (img != null) setState(() => _newImage = File(img.path));
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'prof_photo_failed'.tr(),
        type: AppToastType.error,
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = normalizeOptionalPhone(_phoneController.text);
    setState(() {
      _nameError = name.isEmpty ? 'prof_name_required'.tr() : null;
      _phoneError = phone == null ? 'prof_phone_invalid'.tr() : null;
    });
    if (_nameError != null || _phoneError != null) {
      AppHaptics.error();
      return;
    }

    setState(() => _saving = true);
    try {
      if (_newImage != null) {
        final saved = await _profileService.saveAvatarAsBase64(_newImage!);
        if (saved == null) throw const _PhotoSaveFailed();
      }
      await _profileService.updateProfile(
        name: name,
        // Empty means "no change": clearing a claimed number is not offered.
        phone: (phone == null || phone.isEmpty) ? null : phone,
      );
      if (!mounted) return;
      AppHaptics.success();
      AppToast.show(
        context,
        message: 'prof_saved'.tr(),
        type: AppToastType.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(
        context,
        message: e is PhoneNumberTakenException
            ? 'prof_phone_taken'.tr()
            : e is _PhotoSaveFailed
            ? 'prof_photo_failed'.tr()
            : 'prof_save_failed'.tr(),
        type: AppToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = _nameController.text;
    final existingPhoto = ImageUtils.getAvatarImage(
      widget.currentData['photoUrl'] as String?,
    );
    final ImageProvider? photo = _newImage != null
        ? FileImage(_newImage!)
        : existingPhoto;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            V3TopBar(
              title: 'prof_edit_profile'.tr(),
              leading: V3IconButton.close(context),
              trailing: _saving
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    )
                  : TextButton(
                      key: const ValueKey('edit-profile-save'),
                      onPressed: _save,
                      child: Text(
                        'prof_save'.tr(),
                        style: AppTypography.titleMedium.copyWith(
                          color: p.accent,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 40),
                children: [
                  Center(
                    child: Semantics(
                      button: true,
                      label: 'prof_change_photo'.tr(),
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: _saving ? null : _pickImage,
                        child: photo == null
                            ? V3Avatar(name: name, size: 88)
                            : CircleAvatar(
                                radius: 44,
                                backgroundColor: p.avatarTintFor(name),
                                foregroundImage: photo,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: _saving ? null : _pickImage,
                      child: Text(
                        'prof_change_photo'.tr(),
                        style: AppTypography.labelMedium.copyWith(
                          color: p.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  V3FieldLabel('prof_name_label'.tr()),
                  TextField(
                    key: const ValueKey('edit-profile-name'),
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() => _nameError = null),
                    decoration: InputDecoration(errorText: _nameError),
                  ),
                  const SizedBox(height: 14),
                  V3FieldLabel('prof_email_label'.tr()),
                  TextField(
                    controller: _emailController,
                    readOnly: true,
                    enabled: false,
                    style: AppTypography.bodyLarge.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  V3FieldLabel('prof_phone_optional'.tr()),
                  TextField(
                    key: const ValueKey('edit-profile-phone'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textDirection: ui.TextDirection.ltr,
                    onChanged: (_) => setState(() => _phoneError = null),
                    decoration: InputDecoration(
                      hintText: 'prof_phone_hint'.tr(),
                      errorText: _phoneError,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'prof_privacy_caption'.tr(),
                    style: AppTypography.bodySmall.copyWith(
                      color: p.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSaveFailed implements Exception {
  const _PhotoSaveFailed();
}
