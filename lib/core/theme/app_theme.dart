import 'package:flutter/material.dart';

/// D 端全局设计规范（Design Tokens）。
///
/// 首页、计划、总结、历史、饮食共用同一套字号/间距/卡片样式；
/// 修改这里即可全站调整，不要在页面里写死颜色和尺寸。
class AppTheme {
  static const seedGreen = Color(0xFF176B52);

  // —— 语义色 ——
  /// 主色：训练相关的主视觉与按钮
  static const primary = seedGreen;

  /// 深色品牌底，用于训练主视觉。
  static const deepGreen = Color(0xFF123E32);

  /// 活力强调色，只用于关键进度与主操作。
  static const energy = Color(0xFFC9F45B);

  /// AI 能力色，用于教练、记忆和智能生成状态。
  static const ai = Color(0xFF686CF6);

  static const ink = Color(0xFF14251F);
  static const canvas = Color(0xFFF5F7F3);
  static const subtle = Color(0xFFE8EEE9);

  /// 成功/完成态
  static const success = Color(0xFF246B56);

  /// 未完成/取消态（灰，不用红——取消不是错误）
  static const neutral = Color(0xFF8A8F8C);

  /// 模拟来源标注（琥珀色，明显但非警告）
  static const mockBadge = Color(0xFF9A6B1F);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF123E32), Color(0xFF176B52), Color(0xFF23856A)],
  );

  static const coachGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4E51D8), Color(0xFF777AFB)],
  );

  static ThemeData get light {
    final generated = ColorScheme.fromSeed(
      seedColor: seedGreen,
      brightness: Brightness.light,
    );
    final colors = generated.copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: energy,
      onSecondary: ink,
      tertiary: ai,
      surface: canvas,
      onSurface: ink,
      surfaceContainerLow: const Color(0xFFF0F3EF),
      surfaceContainer: const Color(0xFFEBF0EC),
      surfaceContainerHigh: const Color(0xFFE4EAE5),
      outline: const Color(0xFFCAD5CE),
      outlineVariant: const Color(0xFFE0E7E2),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: const RoundedRectangleBorder(),
          side: const BorderSide(color: Color(0xFFB9C7BE)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDFF2E8),
        indicatorShape: const RoundedRectangleBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? primary
                : const Color(0xFF65716B),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? primary
                : const Color(0xFF65716B),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Color(0xFF7C8781), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFDCE5DF)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFDCE5DF)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: colors.surfaceContainerLow,
        shape: const RoundedRectangleBorder(),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      dialogTheme: const DialogThemeData(shape: RoundedRectangleBorder()),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(),
      ),
      popupMenuTheme: const PopupMenuThemeData(shape: RoundedRectangleBorder()),
      snackBarTheme: const SnackBarThemeData(shape: RoundedRectangleBorder()),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8ECE9),
        thickness: 1,
        space: 1,
      ),
    );
  }
}

/// 排版与间距常量：全站统一。
class AppSpacing {
  static const pagePadding = EdgeInsets.fromLTRB(16, 10, 16, 24);
  static const cardPadding = EdgeInsets.all(18);
  static const gap = 14.0;
  static const gapSmall = 8.0;
}

/// 共享文本样式：正文用 bodyMedium（14sp），标题按层级递减，
/// 不再使用 headlineSmall 做页面标题（在手机上过大）。
class AppText {
  static const pageTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppTheme.ink,
    letterSpacing: -0.2,
  );
  static const cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppTheme.ink,
  );
  static const body = TextStyle(fontSize: 14, height: 1.5, color: AppTheme.ink);
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    color: Color(0xFF68746E),
  );
  static const statNumber = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.1,
    color: AppTheme.ink,
  );
}
