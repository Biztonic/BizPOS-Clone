// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
        // Pre-fill with current app info
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
    return Scaffold(
      appBar: AppBar(title: const Text("Release Management")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Publish New Version",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Updates published here will immediately prompt users to update if their version is lower.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                
                // Version & Build
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 450) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _versionController,
                            decoration: const InputDecoration(
                              labelText: 'Version Name (e.g. 1.0.5)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _buildController,
                            decoration: const InputDecoration(
                              labelText: 'Build Number (e.g. 15)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _versionController,
                            decoration: const InputDecoration(
                              labelText: 'Version Name (e.g. 1.0.5)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _buildController,
                            decoration: const InputDecoration(
                              labelText: 'Build Number (e.g. 15)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 24),

                // URL
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'APK / App Store URL',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                    helperText: 'Direct link to APK or Play Store link'
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Release Notes',
                    hintText: 'What\'s new in this version?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 24),

                // Force Update
                SwitchListTile(
                  title: const Text("Force Update"),
                  subtitle: const Text("Users cannot skip this update"),
                  value: _forceUpdate,
                  onChanged: (val) => setState(() => _forceUpdate = val),
                  contentPadding: EdgeInsets.zero,
                ),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saveConfig,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text("PUBLISH RELEASE"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
