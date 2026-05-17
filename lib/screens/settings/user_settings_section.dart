// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../features/auth/providers/profile_notifier.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_radius.dart';

class UserSettingsSection extends ConsumerStatefulWidget {
  final bool isSubView;
  const UserSettingsSection({super.key, this.isSubView = false});

  @override
  ConsumerState<UserSettingsSection> createState() => _UserSettingsSectionState();
}

class _UserSettingsSectionState extends ConsumerState<UserSettingsSection> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _newPhotoBase64;
  bool _isProcessingImage = false;
  bool _isSaving = false;

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
          return PosScaffold(title: "User Settings", mainContent: Center(child: Text(AppLocalizations.t(context, 'No User Logged In'))));
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

        final content = ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                borderRadius: AppRadius.borderLg,
                                border: Border.all(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                  width: 4,
                                ),
                              ),
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: AppRadius.borderMd,
                                  image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
                                ),
                                child: (imageProvider == null && !_isProcessingImage) 
                                    ? Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant)
                                    : _isProcessingImage ? const Center(child: CircularProgressIndicator()) : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Material(
                                color: Theme.of(context).colorScheme.primary,
                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                                elevation: 4,
                                child: InkWell(
                                  onTap: _pickImage,
                                  customBorder: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
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
                        isLoading: _isSaving,
                        onPressed: _isProcessingImage || _isSaving ? null : () async {
                          setState(() => _isSaving = true);
                          try {
                            final newName = _nameController.text.trim();
                            final newPhone = _phoneController.text.trim();
                            
                            await ref.read(profileNotifierProvider.notifier).updateProfile(
                              name: newName,
                              phoneNumber: newPhone,
                              photoBase64: _newPhotoBase64
                            );
                            
                            if (mounted) {
                              setState(() => _isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppLocalizations.t(context, 'Profile Updated Successfully')), behavior: SnackBarBehavior.floating)
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.adaptiveError(context))
                              );
                            }
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
          );

        if (widget.isSubView) return content;

        return PosScaffold(
          title: "User Settings",
          showSidebar: false,
          mainContent: content,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppRadius.borderMd,
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
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
                const SizedBox(height: AppSpacing.xxs),
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



