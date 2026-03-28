import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_bill_app/services/profile_service.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:split_bill_app/widgets/success_state_widget.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:split_bill_app/widgets/custom_app_header.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const EditProfileScreen({super.key, required this.currentData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  File? _newImage;
  bool _isLoading = false;
  bool _isSuccess = false;

  final ProfileService _profileService = ProfileService();
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentData['displayName'] ?? user?.displayName ?? "",
    );
    _phoneController = TextEditingController(
      text: widget.currentData['phoneNumber'] ?? user?.phoneNumber ?? "",
    );
    _emailController = TextEditingController(
      text: widget.currentData['email'] ?? user?.email ?? "No email linked",
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
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 25,
      maxWidth: 400,
    );
    if (img != null) {
      setState(() => _newImage = File(img.path));
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      if (_newImage != null) {
        await _profileService.saveAvatarAsBase64(_newImage!);
      }
      await _profileService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppHeader(
        title: "Edit Profile",
        infoMessage:
            "✨ Benefits of Completing Profile:\n\n• Better bill splitting experience\n• Easier for friends to find you\n• Personalized app experience\n• Access to premium features",
      ),
      body: _isLoading
          ? const LoadingStateWidget(message: "Saving your changes...")
          : _isSuccess
          ? SuccessStateWidget(
              message: "Profile updated successfully!",
              onAction: () => Navigator.pop(context),
              actionLabel: "Back to Profile",
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Avatar Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.1),
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _newImage != null
                                ? Image.file(_newImage!, fit: BoxFit.cover)
                                : ImageUtils.getAvatarImage(
                                        widget.currentData['photoUrl'],
                                      ) !=
                                      null
                                ? Image(
                                    image: ImageUtils.getAvatarImage(
                                      widget.currentData['photoUrl'],
                                    )!,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Name Field
                  _buildTextField(
                    controller: _nameController,
                    label: "Display Name",
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 20),
                  // Email Field (Read-only)
                  _buildTextField(
                    controller: _emailController,
                    label: "Email Address",
                    icon: Icons.email_outlined,
                    isReadOnly: true,
                  ),
                  const SizedBox(height: 20),
                  // Phone Field
                  _buildTextField(
                    controller: _phoneController,
                    label: "Phone Number",
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 48),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 4,
                        shadowColor: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.4),
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isReadOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            suffixIcon: isReadOnly
                ? Icon(Icons.lock_outline_rounded, color: Colors.grey[400])
                : null,
          ),
          readOnly: isReadOnly,
          enabled: !isReadOnly,
        ),
      ],
    );
  }
}
