import 'package:flutter/material.dart';
import '../../announcement/announcement.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_radius.dart';
import '../../core/design/components/atoms/app_card.dart';

class AudioSettingsSection extends StatefulWidget {
  final bool isSubView;
  const AudioSettingsSection({super.key, this.isSubView = false});

  @override
  State<AudioSettingsSection> createState() => _AudioSettingsSectionState();
}

class _AudioSettingsSectionState extends State<AudioSettingsSection> {
  late AnnouncementSettings _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _settings = AnnouncementSettings.load();
      _isLoading = false;
    });
  }

  void _saveSettings() {
    AnnouncementService().updateSettings(_settings);
  }

  void _testSpeech() {
    AnnouncementService().announce(
      AnnouncementType.paymentSuccess,
      metadata: {'amount': '150'},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Announcements & Alerts',
            style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Configure real-time voice, sound effects, and haptic feedback profiles.',
            style: AppTypography.bodyMedium.copyWith(
              color: isDark ? AppColors.textHintDark : AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 1. Core toggles
          AppCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sound Effects Beeps', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Play chime alerts on item scans, printers, and payments.'),
                  value: _settings.enableSounds,
                  activeColor: AppColors.adaptiveSuccess(context),
                  onChanged: (val) {
                    setState(() {
                      _settings = _settings.copyWith(enableSounds: val);
                      _saveSettings();
                    });
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Text-To-Speech (TTS) Voice', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Announce actions using synthesized voice readouts.'),
                  value: _settings.enableVoice,
                  activeColor: AppColors.adaptiveSuccess(context),
                  onChanged: (val) {
                    setState(() {
                      _settings = _settings.copyWith(enableVoice: val);
                      _saveSettings();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 2. Playback Parameters
          Text('Voice settings', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Volume: ${(_settings.volume * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _settings.volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  activeColor: AppColors.adaptivePrimary(context),
                  onChanged: _settings.enableVoice || _settings.enableSounds
                      ? (val) {
                          setState(() {
                            _settings = _settings.copyWith(volume: val);
                            _saveSettings();
                          });
                        }
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Speech Rate: ${_settings.speechRate.toStringAsFixed(1)}x',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _settings.speechRate,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  activeColor: AppColors.adaptivePrimary(context),
                  onChanged: _settings.enableVoice
                      ? (val) {
                          setState(() {
                            _settings = _settings.copyWith(speechRate: val);
                            _saveSettings();
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 3. Profile & Language
          Text('Preferences & Profiles', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Voice Language',
                    border: OutlineInputBorder(),
                  ),
                  value: _settings.language,
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English (US)')),
                    DropdownMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)')),
                    DropdownMenuItem(value: 'mr', child: Text('मराठी (Marathi)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _settings = _settings.copyWith(language: val);
                        _saveSettings();
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Announcement Filter Profile',
                    border: OutlineInputBorder(),
                  ),
                  value: _settings.profile,
                  items: const [
                    DropdownMenuItem(value: 'Silent', child: Text('Silent (Suppress all voice)')),
                    DropdownMenuItem(
                      value: 'Basic',
                      child: Text('Basic (Payments & Critical alarms only)'),
                    ),
                    DropdownMenuItem(
                      value: 'Business',
                      child: Text('Business (Alarms, payments, printer, sync - default)'),
                    ),
                    DropdownMenuItem(value: 'Verbose', child: Text('Verbose (Announce everything including cart)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _settings = _settings.copyWith(profile: val);
                        _saveSettings();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 4. Test Playback
          Center(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adaptivePrimary(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderMd,
                  ),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Test Announcement Playback', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _testSpeech,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
