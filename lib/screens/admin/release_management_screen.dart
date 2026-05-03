import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';

class ReleaseManagementScreen extends StatefulWidget {
  const ReleaseManagementScreen({super.key});

  @override
  State<ReleaseManagementScreen> createState() => _ReleaseManagementScreenState();
}

class _ReleaseManagementScreenState extends State<ReleaseManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _versionController = TextEditingController();
  final _buildController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();
  bool _forceUpdate = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_version').get();
      if (doc.exists) {
        final data = doc.data()!;
        _versionController.text = data['version'] ?? '';
        _buildController.text = (data['build'] ?? '').toString();
        _urlController.text = data['url'] ?? '';
        _notesController.text = data['notes'] ?? '';
        setState(() {
          _forceUpdate = data['force'] ?? false;
        });
      } else {
        try {
          final info = await PackageInfo.fromPlatform();
          _versionController.text = info.version.isEmpty ? "1.0.0" : info.version;
          _buildController.text = info.buildNumber.isEmpty ? "1" : info.buildNumber;
        } catch (infoError) {
          _versionController.text = "1.0.0";
          _buildController.text = "1";
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading config: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('app_version').set({
        'version': _versionController.text.trim(),
        'build': int.tryParse(_buildController.text.trim()) ?? 0,
        'url': _urlController.text.trim(),
        'notes': _notesController.text.trim(),
        'force': _forceUpdate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Release published successfully!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving release: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PosScaffold(
      title: "Release Management",
      actions: [
        AppButton.primary(
          label: "Publish Release",
          icon: Icons.cloud_upload_outlined,
          onPressed: _isLoading ? null : _saveConfig,
          isLoading: _isLoading,
        ),
        const SizedBox(width: AppSpacing.md),
      ],
      mainContent: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Publish New Version",
                  style: AppTypography.h3,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Updates published here will immediately prompt users to update if their version is lower.",
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)),
                ),
                const SizedBox(height: AppSpacing.xl),
                
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _versionController,
                              labelText: 'Version Name',
                              hintText: 'e.g. 1.0.5',
                              prefixIcon: const Icon(Icons.tag),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _buildController,
                              labelText: 'Build Number',
                              hintText: 'e.g. 15',
                              prefixIcon: const Icon(Icons.numbers),
                              keyboardType: TextInputType.number,
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _urlController,
                        labelText: 'APK / App Store URL',
                        hintText: 'https://...',
                        prefixIcon: const Icon(Icons.link),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _notesController,
                        labelText: 'Release Notes',
                        hintText: 'What\'s new in this version?',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        maxLines: 4,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SwitchListTile(
                        title: Text("Force Update", style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Users cannot skip this update"),
                        value: _forceUpdate,
                        onChanged: (val) => setState(() => _forceUpdate = val),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
