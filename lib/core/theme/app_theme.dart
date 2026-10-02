import 'package:flutter/material.dart';

/// D 端全局设计规范（Design Tokens）。
///
/// 首页、计划、总结、历史、饮食共用同一套字号/间距/卡片样式；
/// 修改这里即可全站调整，不要在页面里写死颜色和尺寸。
class AppTheme {
  static const seedGreen = Color(0xFF246B56);

  // —— 语义色 ——
  /// 主色：训练相关的主视觉与按钮
  static const primary = seedGreen;

  /// 成功/完成态
  static const success = Color(0xFF246B56);

  /// 未完成/取消态（灰，不用红——取消不是错误）
  static const neutral = Color(0xFF8A8F8C);

  /// 模拟来源标注（琥珀色，明显但非警告）
  static const mockBadge = Color(0xFF9A6B1F);

  static ThemeData get light {
    final colors = ColorScheme.fromSeed(
      seedColor: seedGreen,
      surface: const Color(0xFFF4F6F4),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(backgroundColor: colors.surface),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
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
  static const pagePadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const cardPadding = EdgeInsets.all(16);
  static const gap = 12.0;
  static const gapSmall = 8.0;
}

/// 共享文本样式：正文用 bodyMedium（14sp），标题按层级递减，
/// 不再使用 headlineSmall 做页面标题（在手机上过大）。
class AppText {
  static const pageTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const cardTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  static const body = TextStyle(fontSize: 14, height: 1.45);
  static const caption = TextStyle(fontSize: 12, color: Color(0xFF6B7370));
  static const statNumber =
      TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1);
}
