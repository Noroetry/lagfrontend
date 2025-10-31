import 'package:flutter/material.dart';

/// Centralized color and theme definitions for the app.
///
/// Keep UI tokens (colors, text styles, paddings) here so the whole app
/// can be restyled from one place.
class AppColors {
  // Background used for the scaffold and behind popups.
  // Very dark gray to keep depth while avoiding pure black.
  static const Color background = Color.fromARGB(255, 43, 43, 43);

  // Semi-transparent fog overlays used by background effects (rarely used directly).
  static const Color fog1 = Color(0x1FFFFFFF);
  static const Color fog2 = Color(0x0FFFFFFF);

  // Panel surfaces (cards, popups) - default panel color for elevated elements.
  static const Color panel = Color(0xFF141416);
  // Alternate panel variant used for buttons etc.
  static const Color panelAlt = Color(0xFF1A1B1D);

  // Border color for subtle outlines on panels and popups.
  static const Color border = Color(0x33FFFFFF);

  // Disabled element color.
  static const Color disabled = Color(0xFF2A2B2D);

  // Primary text color and secondary text color.
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFBDBDBD);

  // Popup/glass specific tokens
  // Background of translucent popup panels (ARGB: alpha controls transparency)
  // Slightly darker (higher alpha) so popup panels read better over the
  // dark background while still keeping the frosted look.
  static const Color popupBackground = Color.fromARGB(24, 255, 255, 255);
  // Popup border color (slightly visible white overlay)
  static const Color popupBorder = Color.fromARGB(60, 255, 255, 255);
}

/// Global theme and small UI constants.
class AppTheme {
  // Popup visual tokens (used by `PopupForm` widget)
  static const double popupBorderRadius = 16.0;
  static const double popupBlurSigma = 8.0; // blur applied behind popups
  static const EdgeInsets popupPadding = EdgeInsets.all(20.0);
  // Standard maximum width for popup panels to keep consistent sizing
  static const double popupMaxWidth = 520.0;

  // Standard input sizes used across popups/forms
  static const double inputHeight = 44.0;
  static const EdgeInsets inputContentPadding = EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0);
  // Button tweakables for popup action buttons.
  // Duration for the press-state transition (slower -> more tactile feel).
  static const Duration popupButtonAnimationDuration = Duration(milliseconds: 500);
  // Minimal padding to give a wrapped, compact look for popup buttons.
  // Reduced so popup action buttons (used in Login/Welcome) appear compressed
  // and minimal, matching the welcome screen style.
  // Applied globally so popup buttons don't require per-screen overrides.
  static const EdgeInsets popupButtonPadding = EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0);

  // Horizontal spacing between popup action buttons.
  // Use this to keep consistent spacing across all popup action rows.
  static const double popupActionSpacing = 24.0;
  // Default/pressed elevations for tactile depth
  static const double popupButtonElevation = 8.0;
  static const double popupButtonElevationPressed = 2.0;
  // Entrance animation for popups (fade + scale)
  static const Duration popupEntranceDuration = Duration(milliseconds: 260);

  /// Main app ThemeData used in MaterialApp(theme: AppTheme.dark())
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.textPrimary,
      colorScheme: ColorScheme.dark(
        primary: AppColors.textPrimary,
        secondary: AppColors.textSecondary,
        surface: AppColors.panel,
      ),
      // Centralized text styles
      textTheme: const TextTheme(
        // Title for popups and large headings
        titleLarge: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        // Main body text
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        // Secondary/auxiliary text
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        // Labels / button text
        labelLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      // Elevated button defaults
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.panelAlt,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          elevation: 6,
        ),
      ),
      // Text button defaults
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),
    );
  }
}
