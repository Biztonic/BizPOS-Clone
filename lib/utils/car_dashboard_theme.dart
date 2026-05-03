import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CarDashboardTheme {
  // --- DARK MODE: Standout Aesthetics ---
  static const Color neoBackground = Color(0xFF0B0F19); // Rich Deep Blue-Black
  static const Color neoPanel = Color(0xFF151922);     // Slightly lighter panel
  static const Color neoCard = Color(0xFF1E2330);      // Elevated card
  static const Color neoBorder = Color(0xFF2A3441);    // Subtle border
  
  static const Color neoPrimary = Color(0xFF00E5FF);   // Electric Cyan
  static const Color neoSuccess = Color(0xFF00E676);   // Neon Green
  static const Color neoWarning = Color(0xFFFFC400);   // Amber
  static const Color neoDanger = Color(0xFFFF1744);    // Red Accent
  
  static const Color neoTextPrimary = Color(0xFFFFFFFF);
  static const Color neoTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color neoTextMuted = Color(0xFF475569);     // Slate 600

  // --- LIGHT MODE: Crystal POS Pro ---
  static const Color crystalBackground = Color(0xFFF1F5F9);
  static const Color crystalPanel = Color(0xFFFFFFFF);
  static const Color crystalCard = Color(0xFFFFFFFF);
  static const Color crystalBorder = Color(0xFFE2E8F0);

  static const Color crystalPrimary = Color(0xFF2563EB);
  static const Color crystalSuccess = Color(0xFF22C55E);
  static const Color crystalWarning = Color(0xFFF59E0B);
  static const Color crystalDanger = Color(0xFFEF4444);

  static const Color crystalTextPrimary = Color(0xFF0F172A);
  static const Color crystalTextSecondary = Color(0xFF64748B);
  static const Color crystalTextMuted = Color(0xFF94A3B8);

  // --- ACCESSORS ---
  static Color backgroundColor(bool isDark) => isDark ? neoBackground : crystalBackground;
  static Color panelColor(bool isDark) => isDark ? neoPanel : crystalPanel;
  static Color cardColor(bool isDark) => isDark ? neoCard : crystalCard;
  static Color borderColor(bool isDark) => isDark ? neoBorder : crystalBorder;
  
  static Color primaryColor(bool isDark) => isDark ? neoPrimary : crystalPrimary;
  static Color secondaryColor(bool isDark) => isDark ? neoSuccess : crystalPrimary; 
  
  static Color successColor(bool isDark) => isDark ? neoSuccess : crystalSuccess;
  static Color warningColor(bool isDark) => isDark ? neoWarning : crystalWarning;
  static Color dangerColor(bool isDark) => isDark ? neoDanger : crystalDanger;

  static Color textColor(bool isDark) => isDark ? neoTextPrimary : crystalTextPrimary;
  static Color subTextColor(bool isDark) => isDark ? neoTextSecondary : crystalTextSecondary;
  static Color mutedTextColor(bool isDark) => isDark ? neoTextMuted : crystalTextMuted;

  // Aliases for compatibility
  static const Color bgDark = neoBackground; 
  static const Color bgPanel = neoPanel; 
  static const Color overlayLight = Color(0x00FFFFFF); 
 
  static const Color neonBlue = neoPrimary; 
  static const Color electricGreen = neoSuccess;
  static const Color alertRed = neoDanger;
  static const Color warningAmber = neoWarning;
  
  static const Color accentSuccess = neoSuccess;
  static const Color accentPrimary = neoPrimary;
  static const Color accentDanger = neoDanger;

  static const List<Color> lightCardColors = [
      Color(0xFFFFFFFF), 
      Color(0xFFF0FDF4), 
      Color(0xFFEFF6FF), 
      Color(0xFFFFFBEB), 
      Color(0xFFFEF2F2), 
      Color(0xFFF5F3FF), 
  ];
  static const List<Color> darkCardColors = [
      Color(0xFF1E293B),
      Color(0xFF14292D),
      Color(0xFF172554),
      Color(0xFF2A1C08),
      Color(0xFF2B1212),
      Color(0xFF201836),
  ];

  static Color getCardColor(int index, bool isDark) {
    if (isDark) return darkCardColors[index % darkCardColors.length];
    return lightCardColors[index % lightCardColors.length];
  }

  // Getters that depend on context (non-const)
  static Color glassColor(bool isDark) => isDark ? Colors.white.withValues(alpha: 0.03) : Colors.transparent; 
  
  // --- TYPOGRAPHY (Inter Pro) ---
  static TextStyle get productTitle => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle get priceStyle => GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700);
  static TextStyle get labelStyle => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500);
  static TextStyle get quantityStyle => GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700); 
  
  // Compat getters
  static TextStyle get numericLarge => priceStyle; 
  static TextStyle get numericMedium => priceStyle.copyWith(fontSize: 20);
  static TextStyle get buttonText => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600);
  
  // --- GRADIENTS ---
  static LinearGradient primaryGradient(bool isDark) => LinearGradient(
    colors: isDark ? [const Color(0xFF00E5FF), const Color(0xFF2979FF)] : [crystalPrimary, crystalPrimary.withValues(alpha: 0.8)],
    begin: Alignment.topLeft, 
    end: Alignment.bottomRight
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Colors.transparent, Colors.transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static final List<BoxShadow> neonGlowBlue = [
     BoxShadow(color: neoPrimary.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)
  ]; 
  
  static List<BoxShadow> cardShadow(bool isDark) => [
     BoxShadow(
       color: isDark ? Colors.black.withValues(alpha: 0.5) : const Color(0xFF0F172A).withValues(alpha: 0.08),
       blurRadius: isDark ? 20 : 14,
       offset: const Offset(0, 8)
     )
  ];

  static Color getIconColor(String label, bool isDark) {
      if (['POS', 'POS TERM', 'DASHBOARD'].contains(label.toUpperCase())) return primaryColor(isDark);
      if (['SALES', 'SALES LOG', 'REPORTS'].contains(label.toUpperCase())) return successColor(isDark);
      if (['INVENTORY', 'STOCK'].contains(label.toUpperCase())) return warningColor(isDark);
      if (['EXPENSES', 'LOGOUT'].contains(label.toUpperCase())) return dangerColor(isDark);
      return subTextColor(isDark);
  }

  static ThemeData getThemeData({bool isDark = true}) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: backgroundColor(isDark),
      primaryColor: primaryColor(isDark),
      canvasColor: panelColor(isDark),
      cardColor: cardColor(isDark),
      dividerColor: borderColor(isDark),
      
      // fontFamily: GoogleFonts.inter().fontFamily, // Removed global override to protect Icons
      textTheme: GoogleFonts.interTextTheme(isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme).apply(
        bodyColor: textColor(isDark),
        displayColor: textColor(isDark),
      ),

      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primaryColor(isDark),
        onPrimary: isDark ? const Color(0xFF0B0F19) : Colors.white,
        secondary: successColor(isDark), 
        onSecondary: isDark ? const Color(0xFF0B0F19) : Colors.white,
        surface: panelColor(isDark),
        onSurface: textColor(isDark),
        surfaceContainer: cardColor(isDark),
        error: dangerColor(isDark),
        onError: Colors.white,
      ),

      cardTheme: CardThemeData(
        color: cardColor(isDark),
        elevation: 0, 
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(16),
           side: BorderSide(color: borderColor(isDark), width: 1), 
        ),
      ),
      
      iconTheme: IconThemeData(
        color: primaryColor(isDark),
      ),
      
      dialogTheme: DialogThemeData(
        backgroundColor: panelColor(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor(isDark), width: 1),
        ),
        titleTextStyle: priceStyle.copyWith(color: textColor(isDark)),
      ),
    );
  }
}
