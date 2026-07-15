import 'package:flutter/material.dart';
import '../../announcement/announcement.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_radius.dart';
import '../../core/design/components/atoms/app_card.dart';
import 'package:file_picker/file_picker.dart';

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

  Future<void> _uploadMarketingAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        final name = file.name;
        if (bytes != null) {
          await AnnouncementService().addMarketingAudio(name, bytes);
          setState(() {
            _settings = AnnouncementService().settings;
          });
        }
      }
    } catch (_) {}
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
                    DropdownMenuItem(value: 'Business', child: Text('Business (Alarms, payments, printer, sync - default)')),
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
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Touch Interaction Sound',
                    border: OutlineInputBorder(),
                  ),
                  value: (() {
                    final val = _settings.interactionSound;
                    if (val == 'click') return '1';
                    if (val == 'beep') return '6';
                    if (val == 'chime') return '11';
                    return val;
                  })(),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None (Muted)')),
                    DropdownMenuItem(value: '1', child: Text('Sound 1: Subtle Click')),
                    DropdownMenuItem(value: '2', child: Text('Sound 2: Tech Click')),
                    DropdownMenuItem(value: '3', child: Text('Sound 3: High Tick')),
                    DropdownMenuItem(value: '4', child: Text('Sound 4: Wood Click')),
                    DropdownMenuItem(value: '5', child: Text('Sound 5: Pop Click')),
                    DropdownMenuItem(value: '6', child: Text('Sound 6: Standard Beep')),
                    DropdownMenuItem(value: '7', child: Text('Sound 7: High Beep')),
                    DropdownMenuItem(value: '8', child: Text('Sound 8: Low Beep')),
                    DropdownMenuItem(value: '9', child: Text('Sound 9: Double Beep')),
                    DropdownMenuItem(value: '10', child: Text('Sound 10: Triple Beep')),
                    DropdownMenuItem(value: '11', child: Text('Sound 11: Ascending Chime')),
                    DropdownMenuItem(value: '12', child: Text('Sound 12: Descending Chime')),
                    DropdownMenuItem(value: '13', child: Text('Sound 13: Major Triad Chord')),
                    DropdownMenuItem(value: '14', child: Text('Sound 14: Ding Dong Alert')),
                    DropdownMenuItem(value: '15', child: Text('Sound 15: Ring Chime')),
                    DropdownMenuItem(value: '16', child: Text('Sound 16: Sci-Fi Sweep Up')),
                    DropdownMenuItem(value: '17', child: Text('Sound 17: Sci-Fi Sweep Down')),
                    DropdownMenuItem(value: '18', child: Text('Sound 18: Retro Laser')),
                    DropdownMenuItem(value: '19', child: Text('Sound 19: Alert Ping')),
                    DropdownMenuItem(value: '20', child: Text('Sound 20: Digital Alarm Pulse')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _settings = _settings.copyWith(interactionSound: val);
                        _saveSettings();
                        AnnouncementService().playInteractionSound();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 4. Marketing Announcements (Local Offline Storage)
          Text('Marketing Announcements', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Upload custom audio promos. All files are stored locally on this device and never uploaded to the cloud.',
            style: AppTypography.bodySmall.copyWith(
              color: isDark ? AppColors.textHintDark : AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Marketing Play Mode',
                    border: OutlineInputBorder(),
                  ),
                  value: _settings.marketingPlayMode,
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('Disabled (Muted)')),
                    DropdownMenuItem(value: 'loop', child: Text('Continuous Loop (Rotation)')),
                    DropdownMenuItem(value: 'interval', child: Text('Scheduled Interval')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _settings = _settings.copyWith(marketingPlayMode: val);
                        _saveSettings();
                      });
                    }
                  },
                ),
                if (_settings.marketingPlayMode == 'interval') ...[
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Play Interval',
                      border: OutlineInputBorder(),
                    ),
                    value: _settings.marketingIntervalSeconds,
                    items: const [
                      DropdownMenuItem(value: 60, child: Text('Every 1 Minute')),
                      DropdownMenuItem(value: 300, child: Text('Every 5 Minutes (Default)')),
                      DropdownMenuItem(value: 600, child: Text('Every 10 Minutes')),
                      DropdownMenuItem(value: 1800, child: Text('Every 30 Minutes')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _settings = _settings.copyWith(marketingIntervalSeconds: val);
                          _saveSettings();
                        });
                      }
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Local Audio Tracks (${AnnouncementService().marketingAudios.length})',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.adaptivePrimary(context),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderSm,
                        ),
                      ),
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Add Audio Track'),
                      onPressed: _uploadMarketingAudio,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (AnnouncementService().marketingAudios.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(
                      child: Text(
                        'No local audio tracks uploaded yet.',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.secondary),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: AnnouncementService().marketingAudios.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final audio = AnnouncementService().marketingAudios[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.audiotrack, color: AppColors.secondary),
                        title: Text(audio.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Size: ${(audio.bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(2)} MB • Local Storage',
                          style: AppTypography.bodySmall,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () async {
                            await AnnouncementService().deleteMarketingAudio(audio.id);
                            setState(() {
                              _settings = AnnouncementService().settings;
                            });
                          },
                        ),
                      );
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
