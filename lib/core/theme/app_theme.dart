import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dynamic theme-aware colors backed by the active [AppThemePalette].
class AppColors {
  AppColors._();

  static AppThemePalette _active = AppThemePalette.royalLight;

  /// Syncs static [AppColors] getters with the active [palette].
  static void applyPalette(AppThemePalette palette) {
    _active = palette;
  }

  static bool get isDark => _active.isDark;

  // Core backgrounds & surfaces
  static Color get background => _active.background;
  static Color get surface => _active.surface;
  static Color get cardSurface => _active.cardSurface;
  static Color get border => _active.border;

  static Color get surfaceSubtle => isDark
      ? Color.lerp(_active.cardSurface, _active.textPrimary, 0.05)!
      : const Color(0xFFF8FAFC);
  static Color get surfaceMuted => isDark
      ? Color.lerp(_active.cardSurface, _active.textPrimary, 0.10)!
      : const Color(0xFFF1F5F9);
  static Color get borderStrong => isDark
      ? Color.lerp(_active.border, _active.textPrimary, 0.18)!
      : const Color(0xFFCBD5E1);
  static Color get snackBarBg =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFF1E1B2E);

  // Brand accents
  static Color get primary => _active.primary;
  static Color get secondary => _active.secondary;
  static Color get primarySoft => _active.primarySoft;

  // Text hierarchy
  static Color get textPrimary => _active.textPrimary;
  static Color get textSecondary => _active.textSecondary;

  // Status indicators (vibrant semantic tones)
  static const success = Color(0xFF10B981); // Safe / Approved
  static const warning = Color(0xFFF59E0B); // Warning / Room Change
  static const danger = Color(0xFFEF4444); // Danger / Cancelled
  static const live = Color(0xFF8B5CF6);

  // Dark/light-adaptive semantic surfaces & text tokens
  static Color get urgentBg =>
      isDark ? const Color(0xFF1B1508) : const Color(0xFFFFFBEB);
  static Color get warningBg =>
      isDark ? const Color(0xFF2B200B) : const Color(0xFFFEF3C7);
  static Color get warningBorder =>
      isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A);
  static Color get warningText =>
      isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
  static Color get warningTextDeep =>
      isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);

  static Color get successBg =>
      isDark ? const Color(0xFF0A261D) : const Color(0xFFECFDF5);
  static Color get successBgStrong =>
      isDark ? const Color(0xFF0D3326) : const Color(0xFFD1FAE5);
  static Color get successBorder =>
      isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0);
  static Color get successText =>
      isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);

  static Color get dangerBg =>
      isDark ? const Color(0xFF2B1115) : const Color(0xFFFEF2F2);
  static Color get dangerBgStrong =>
      isDark ? const Color(0xFF3A151B) : const Color(0xFFFEE2E2);
  static Color get dangerBorder =>
      isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA);
  static Color get dangerText =>
      isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);

  static Color get infoBg =>
      isDark ? const Color(0xFF161A36) : const Color(0xFFEEF2FF);
  static Color get infoBorder =>
      isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE);
  static Color get infoText =>
      isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5);

  static Color get blueBg =>
      isDark ? const Color(0xFF0F1E36) : const Color(0xFFEFF6FF);
  static Color get blueBorder =>
      isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
  static Color get blueText =>
      isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);

  // Signature hero gradient
  static LinearGradient get brandGradient => _active.heroGradient;
  static LinearGradient get subtlePurpleGradient => _active.heroGradient;
}

class AppRadii {
  AppRadii._();

  static const double card = 16.0;
  static const double hero = 20.0;
  static const double input = 12.0;
  static const double pill = 999.0;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => AppColors.isDark
      ? const []
      : [
          BoxShadow(
            color: const Color(0xFF1E1B2E).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];

  static List<BoxShadow> get hero => [
        BoxShadow(
          color: AppColors.primary
              .withValues(alpha: AppColors.isDark ? 0.22 : 0.28),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get floatingBar => [
        BoxShadow(
          color: Colors.black.withValues(alpha: AppColors.isDark ? 0.45 : 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}

class AppTheme {
  AppTheme._();

  static SystemUiOverlayStyle get overlayStyle =>
      overlayStyleFor(AppThemePreset.royalLight);

  static SystemUiOverlayStyle overlayStyleFor(AppThemePreset preset) {
    final palette = AppThemePalette.forPreset(preset);
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          palette.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: palette.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: palette.background,
      systemNavigationBarIconBrightness:
          palette.isDark ? Brightness.light : Brightness.dark,
    );
  }

  static ThemeData get light => forPreset(AppThemePreset.royalLight);

  static ThemeData forPreset(AppThemePreset preset) {
    final palette = AppThemePalette.forPreset(preset);
    AppColors.applyPalette(palette);
    final brightness = palette.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    ).copyWith(
      primary: palette.primary,
      onPrimary: Colors.white,
      secondary: palette.secondary,
      onSecondary: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.border,
      outlineVariant: palette.border,
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: BorderSide(color: palette.border, width: 1.0),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1.0]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyleFor(preset),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.textSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: palette.textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyMedium
            ?.copyWith(color: palette.textSecondary.withValues(alpha: 0.8)),
        labelStyle:
            textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
        prefixIconColor: palette.textSecondary,
        border: inputBorder(palette.border),
        enabledBorder: inputBorder(palette.border),
        focusedBorder: inputBorder(palette.primary, 1.5),
        errorBorder: inputBorder(AppColors.danger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.input),
          ),
          textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.input),
          ),
          textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.primarySoft,
        side: BorderSide(color: palette.border),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: palette.primary,
          fontWeight: FontWeight.w700,
        ),
        checkmarkColor: palette.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.snackBarBg,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.cardSurface,
          foregroundColor: palette.textPrimary,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.input),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.primary,
        unselectedLabelColor: palette.textSecondary,
        indicatorColor: palette.primary,
        dividerColor: palette.border,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: palette.border, width: 1.5),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.primary;
          return palette.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.primarySoft;
          return palette.surface;
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        textColor: palette.textPrimary,
      ),
    );
  }
}

/// Curated App Theme Cosmetics (Free + Premium 50-100 Credit unlocks)
enum AppThemePreset {
  royalLight(
    id: 'royal_light',
    name: 'Royal Alabaster',
    tagline: 'Crisp signature white & royal purple',
    costCredits: 0,
    isDark: false,
  ),
  oceanSlate(
    id: 'ocean_slate',
    name: 'Ocean Breeze',
    tagline: 'Clean cool slate with cobalt blue accents',
    costCredits: 0,
    isDark: false,
  ),
  auroraViolet(
    id: 'aurora_violet',
    name: 'Aurora Lavender',
    tagline: 'Soft iridescent violet daylight edition',
    costCredits: 50,
    isDark: false,
  ),
  cobaltCarbon(
    id: 'cobalt_carbon',
    name: 'Stealth Cobalt (Boys)',
    tagline: 'Boys Edition • Sleek carbon navy dark theme with electric cobalt accents',
    costCredits: 50,
    isDark: true,
  ),
  blushRose(
    id: 'blush_rose',
    name: 'Blush Rose (Girls)',
    tagline: 'Girls Edition • Soft sakura pink daylight theme with berry rose accents',
    costCredits: 50,
    isDark: false,
  ),
  midnightPurple(
    id: 'midnight_purple',
    name: 'Midnight Royal Purple',
    tagline: 'Deep twilight dark mode with neon amethyst',
    costCredits: 75,
    isDark: true,
  ),
  obsidianOled(
    id: 'obsidian_oled',
    name: 'Obsidian OLED Dark',
    tagline: 'True pitch-black AMOLED battery saver + violet glow',
    costCredits: 85,
    isDark: true,
  ),
  cyberEmerald(
    id: 'cyber_emerald',
    name: 'Cyber Emerald Dark',
    tagline: 'Dark carbon glass with emerald matrix accents',
    costCredits: 90,
    isDark: true,
  ),
  obsidianGold(
    id: 'obsidian_gold',
    name: 'Obsidian Gold Prestige',
    tagline: 'Luxury onyx dark theme with metallic gold highlights',
    costCredits: 100,
    isDark: true,
  );

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.tagline,
    required this.costCredits,
    required this.isDark,
  });

  final String id;
  final String name;
  final String tagline;
  final int costCredits;
  final bool isDark;

  bool get isFree => costCredits == 0;

  static AppThemePreset fromId(String? id) {
    return AppThemePreset.values.firstWhere(
      (p) => p.id == id,
      orElse: () => AppThemePreset.royalLight,
    );
  }
}

/// Custom Lecture Alarm Sounds (Free + Unlockable 50-75 Credits)
enum AlarmSoundPreset {
  classicAlarm(
    id: 'classic_alarm',
    rawResName: null,
    name: 'Classic Clock Bell',
    tagline: 'Standard system alarm ringtone & steady buzz',
    costCredits: 0,
  ),
  oversimplifiedAlarm(
    id: 'oversimplified_alarm',
    rawResName: 'alarm_oversimplified',
    name: 'Clean Pulse Alarm',
    tagline: 'Crisp minimalist bundled alarm clock tone',
    costCredits: 50,
  ),
  dreamcoreAlarm(
    id: 'dreamcore_alarm',
    rawResName: 'alarm_dreamcore',
    name: 'Dreamcore Ambient Alarm',
    tagline: 'Melodic dreamy bundled alarm soundtrack',
    costCredits: 60,
  ),
  chiptuneAlarm(
    id: 'chiptune_alarm',
    rawResName: 'alarm_chiptune',
    name: 'Chiptune Retro Alarm',
    tagline: 'High-energy 8-bit chiptune alarm & double-pulse haptics',
    costCredits: 75,
  );

  const AlarmSoundPreset({
    required this.id,
    required this.rawResName,
    required this.name,
    required this.tagline,
    required this.costCredits,
  });

  final String id;
  final String? rawResName;
  final String name;
  final String tagline;
  final int costCredits;

  bool get isFree => costCredits == 0;

  static AlarmSoundPreset fromId(String? id) {
    switch (id) {
      case 'gentle_chime':
        return AlarmSoundPreset.oversimplifiedAlarm;
      case 'melody_ringtone':
        return AlarmSoundPreset.dreamcoreAlarm;
      case 'tactical_pulse':
        return AlarmSoundPreset.chiptuneAlarm;
      default:
        return AlarmSoundPreset.values.firstWhere(
          (p) => p.id == id,
          orElse: () => AlarmSoundPreset.classicAlarm,
        );
    }
  }
}

/// Custom Selectable Notification Sound Effects (bundled in Android res/raw)
enum NotificationSoundPreset {
  bubblePop(
    id: 'bubble_pop',
    rawResName: 'notif_bubble_pop',
    name: 'Bubble Pop Alert',
    tagline: 'Crisp soft bubble pop notification effect',
    costCredits: 0,
  ),
  interfaceChime(
    id: 'interface_chime',
    rawResName: 'notif_interface_chime',
    name: 'Soft Interface Chime',
    tagline: 'Modern clean chime for reminders & updates',
    costCredits: 0,
  ),
  systemDefault(
    id: 'system_default',
    rawResName: null,
    name: 'System Default',
    tagline: 'Device default notification ringtone',
    costCredits: 0,
  );

  const NotificationSoundPreset({
    required this.id,
    required this.rawResName,
    required this.name,
    required this.tagline,
    required this.costCredits,
  });

  final String id;
  final String? rawResName;
  final String name;
  final String tagline;
  final int costCredits;

  bool get isFree => costCredits == 0;

  static NotificationSoundPreset fromId(String? id) {
    return NotificationSoundPreset.values.firstWhere(
      (p) => p.id == id,
      orElse: () => NotificationSoundPreset.bubblePop,
    );
  }
}

class AppThemePalette extends ThemeExtension<AppThemePalette> {
  final Color background;
  final Color surface;
  final Color cardSurface;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color primarySoft;
  final Color textPrimary;
  final Color textSecondary;
  final LinearGradient heroGradient;
  final bool isDark;

  const AppThemePalette({
    required this.background,
    required this.surface,
    required this.cardSurface,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.primarySoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.heroGradient,
    required this.isDark,
  });

  static const AppThemePalette royalLight = AppThemePalette(
    background: Color(0xFFFAFAFE),
    surface: Color(0xFFFFFFFF),
    cardSurface: Color(0xFFFFFFFF),
    border: Color(0xFFECE9F8),
    primary: Color(0xFF6D28D9),
    secondary: Color(0xFF4C1D95),
    primarySoft: Color(0xFFF3EEFF),
    textPrimary: Color(0xFF1E1B2E),
    textSecondary: Color(0xFF6E6A86),
    heroGradient: LinearGradient(
      colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    isDark: false,
  );

  static AppThemePalette forPreset(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.royalLight:
        return royalLight;
      case AppThemePreset.oceanSlate:
        return const AppThemePalette(
          background: Color(0xFFF6FAFF),
          surface: Color(0xFFFFFFFF),
          cardSurface: Color(0xFFFFFFFF),
          border: Color(0xFFDBEAFE),
          primary: Color(0xFF2563EB),
          secondary: Color(0xFF1E3A8A),
          primarySoft: Color(0xFFEFF6FF),
          textPrimary: Color(0xFF0F172A),
          textSecondary: Color(0xFF64748B),
          heroGradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          isDark: false,
        );
      case AppThemePreset.auroraViolet:
        return const AppThemePalette(
          background: Color(0xFFF5F0FF),
          surface: Color(0xFFFFFFFF),
          cardSurface: Color(0xFFFFFFFF),
          border: Color(0xFFDDD6FE),
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF9333EA),
          primarySoft: Color(0xFFEDE9FE),
          textPrimary: Color(0xFF2E1065),
          textSecondary: Color(0xFF5B4B8A),
          heroGradient: LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          isDark: false,
        );
      case AppThemePreset.cobaltCarbon:
        return const AppThemePalette(
          background: Color(0xFF070D19),
          surface: Color(0xFF0E172A),
          cardSurface: Color(0xFF132038),
          border: Color(0xFF23375A),
          primary: Color(0xFF0284C7),
          secondary: Color(0xFF0369A1),
          primarySoft: Color(0xFF102A43),
          textPrimary: Color(0xFFF0F9FF),
          textSecondary: Color(0xFF94B4D4),
          heroGradient: LinearGradient(
            colors: [Color(0xFF0284C7), Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          isDark: true,
        );
      case AppThemePreset.blushRose:
        return const AppThemePalette(
          background: Color(0xFFFFF5F8),
          surface: Color(0xFFFFFFFF),
          cardSurface: Color(0xFFFFFFFF),
          border: Color(0xFFFBCFE8),
          primary: Color(0xFFDB2777),
          secondary: Color(0xFF9D174D),
          primarySoft: Color(0xFFFCE7F3),
          textPrimary: Color(0xFF3B0726),
          textSecondary: Color(0xFF834868),
          heroGradient: LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          isDark: false,
        );
      case AppThemePreset.midnightPurple:
        return const AppThemePalette(
          background: Color(0xFF0B0A16),
          surface: Color(0xFF151328),
          cardSurface: Color(0xFF1A1733),
          border: Color(0xFF2E2759),
          primary: Color(0xFFA855F7),
          secondary: Color(0xFF6D28D9),
          primarySoft: Color(0xFF2A1E4E),
          textPrimary: Color(0xFFF5F3FF),
          textSecondary: Color(0xFFB4AFD6),
          heroGradient: LinearGradient(
            colors: [Color(0xFF7E22CE), Color(0xFF3B0764)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          isDark: true,
        );
      case AppThemePreset.obsidianOled:
        return const AppThemePalette(
          background: Color(0xFF000000),
          surface: Color(0xFF0C0C12),
          cardSurface: Color(0xFF12121B),
          border: Color(0xFF27273A),
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFF5B21B6),
          primarySoft: Color(0xFF1E1636),
          textPrimary: Color(0xFFF8FAFC),
          textSecondary: Color(0xFFA3B1C6),
          heroGradient: LinearGradient(
            colors: [Color(0xFF6D28D9), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          isDark: true,
        );
      case AppThemePreset.cyberEmerald:
        return const AppThemePalette(
          background: Color(0xFF050C0A),
          surface: Color(0xFF0C1A16),
          cardSurface: Color(0xFF11241E),
          border: Color(0xFF1F4337),
          primary: Color(0xFF10B981),
          secondary: Color(0xFF047857),
          primarySoft: Color(0xFF0F2D24),
          textPrimary: Color(0xFFECFDF5),
          textSecondary: Color(0xFF94B8AC),
          heroGradient: LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF064E3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          isDark: true,
        );
      case AppThemePreset.obsidianGold:
        return const AppThemePalette(
          background: Color(0xFF09090B),
          surface: Color(0xFF141419),
          cardSurface: Color(0xFF1C1C23),
          border: Color(0xFF3F3216),
          primary: Color(0xFFD97706),
          secondary: Color(0xFF92400E),
          primarySoft: Color(0xFF2E230B),
          textPrimary: Color(0xFFFEFCE8),
          textSecondary: Color(0xFFC4B9A5),
          heroGradient: LinearGradient(
            colors: [Color(0xFFB45309), Color(0xFF451A03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          isDark: true,
        );
    }
  }

  @override
  AppThemePalette copyWith({
    Color? background,
    Color? surface,
    Color? cardSurface,
    Color? border,
    Color? primary,
    Color? secondary,
    Color? primarySoft,
    Color? textPrimary,
    Color? textSecondary,
    LinearGradient? heroGradient,
    bool? isDark,
  }) {
    return AppThemePalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      cardSurface: cardSurface ?? this.cardSurface,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      primarySoft: primarySoft ?? this.primarySoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      heroGradient: heroGradient ?? this.heroGradient,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppThemePalette lerp(ThemeExtension<AppThemePalette>? other, double t) {
    if (other is! AppThemePalette) return this;
    return AppThemePalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      heroGradient: t < 0.5 ? heroGradient : other.heroGradient,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension AppThemePaletteX on BuildContext {
  AppThemePalette get palette =>
      Theme.of(this).extension<AppThemePalette>() ??
      AppThemePalette.royalLight;
}
