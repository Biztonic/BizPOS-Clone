// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../features/auth/providers/profile_notifier.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/density/app_density.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';

class UserSettingsSection extends ConsumerStatefulWidget {
  const UserSettingsSection({super.key});

  @override
  ConsumerState<UserSettingsSection> createState() => _UserSettingsSectionState();
}

class _UserSettingsSectionState extends ConsumerState<UserSettingsSection> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _newPhotoBase64;
  bool _isProcessingImage = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500);

    if (pickedFile != null) {
      setState(() => _isProcessingImage = true);
      try {
        final bytes = await pickedFile.readAsBytes();
        
        img.Image? image = img.decodeImage(bytes);
        if (image == null) throw Exception("Could not decode image");

        img.Image thumbnail = img.copyResize(image, width: 200);
        List<int> compressedBytes = img.encodeJpg(thumbnail, quality: 70);
        final base64String = base64Encode(compressedBytes);

        if (mounted) {
           setState(() {
             _newPhotoBase64 = base64String;
           });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error processing image: $e")));
      } finally {
        if (mounted) setState(() => _isProcessingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);
    
    return profileState.when(
      loading: () => const PosScaffold(title: "User Settings", mainContent: Center(child: CircularProgressIndicator())),
      error: (err, stack) => PosScaffold(title: "User Settings", mainContent: Center(child: Text("Error: $err"))),
      data: (user) {
        if (user == null) {
          return const PosScaffold(title: "User Settings", mainContent: Center(child: Text("No User Logged In")));
        }

        // Only update controllers if they are empty (initial load)
        if (_nameController.text.isEmpty) {
          _nameController.text = user.name;
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = user.phoneNumber ?? '';
        }

        ImageProvider? imageProvider;
        if (_newPhotoBase64 != null) {
           imageProvider = MemoryImage(base64Decode(_newPhotoBase64!));
        } else if (user.photoBase64 != null && user.photoBase64!.isNotEmpty) {
           imageProvider = MemoryImage(base64Decode(user.photoBase64!));
        }

        return PosScaffold(
          title: "User Settings",
          mainContent: ListView(
            padding: EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                  width: 4,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                backgroundImage: imageProvider,
                                child: (imageProvider == null && !_isProcessingImage) 
                                    ? Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant)
                                    : _isProcessingImage ? const CircularProgressIndicator() : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Material(
                                color: Theme.of(context).colorScheme.primary,
                                shape: const CircleBorder(),
                                elevation: 4,
                                child: InkWell(
                                  onTap: _pickImage,
                                  customBorder: const CircleBorder(),
                                  child: Padding(
                                    padding: EdgeInsets.all(AppSpacing.sm),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppTextField(
                        controller: _nameController,
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _phoneController,
                        labelText: 'Phone Number',
                        hintText: 'Enter your phone number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildReadOnlyField(
                        context,
                        label: "Email",
                        value: user.email,
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildReadOnlyField(
                        context,
                        label: "Role",
                        value: user.role,
                        icon: Icons.security_outlined,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: "Save Profile",
                        onPressed: _isProcessingImage ? null : () async {
                          final newName = _nameController.text.trim();
                          final newPhone = _phoneController.text.trim();
                          
                          await ref.read(profileNotifierProvider.notifier).updateProfile(
                            name: newName,
                            phoneNumber: newPhone,
                            photoBase64: _newPhotoBase64
                          );
                          
                          if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text("Profile Updated Successfully"), behavior: SnackBarBehavior.floating)
                             );
                          }
                        },
                        variant: AppButtonVariant.primary,
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReadOnlyField(BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
