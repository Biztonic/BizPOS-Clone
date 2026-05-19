import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currentLocale = localeProvider.locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredLanguages = LocaleProvider.supportedLanguages.where((lang) {
      final name = lang['name']!.toLowerCase();
      final code = lang['code']!.toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || code.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'language_settings')),
        elevation: 0,
        backgroundColor: AppColors.transparent,
        foregroundColor: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: AppLocalizations.t(context, 'search'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                filled: true,
                fillColor: AppColors.surfaceVariant(context),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                childAspectRatio: 1.5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: filteredLanguages.length,
              itemBuilder: (context, index) {
                final lang = filteredLanguages[index];
                final code = lang['code']!;
                final name = lang['name']!;
                final isSelected = currentLocale == code;

                return GestureDetector(
                  onTap: () => localeProvider.setLocale(code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? Theme.of(context).primaryColor
                        : AppColors.surface(context),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: isSelected 
                          ? Theme.of(context).primaryColor
                          : (isDark ? AppColors.border(context) : AppColors.border(context)),
                        width: 2,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ] : [],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getNativeIndicator(code),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppColors.surfaceLight : (isDark ? AppColors.textSecondaryDark : AppColors.textPrimaryLight),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.surfaceLight : (isDark ? Colors.white60 : AppColors.textSecondaryLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Positioned(
                            top: AppSpacing.sm,
                            right: AppSpacing.sm,
                            child: Icon(Icons.check_circle, color: AppColors.surfaceLight, size: 20),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getNativeIndicator(String code) {
    switch (code) {
      case 'en': return 'Aa';
      case 'hi': return 'à¤…';
      case 'bn': return 'à¦…';
      case 'mr': return 'à¤…';
      case 'te': return 'à°…';
      case 'ta': return 'à®…';
      case 'gu': return 'àª…';
      case 'ur': return 'Ø§';
      case 'kn': return 'à²…';
      case 'or': return 'à¬…';
      case 'ml': return 'à´…';
      default: return 'A';
    }
  }
}


