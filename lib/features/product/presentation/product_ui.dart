import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ProductHero extends StatelessWidget {
  const ProductHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.background = Colors.white,
    this.accent = AppTheme.primary,
    this.footer,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color accent;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: background,
      borderRadius: AppRadius.hero,
      border: Border.all(color: accent.withValues(alpha: 0.14)),
    ),
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          right: -42,
          top: -54,
          child: Container(
            width: 138,
            height: 138,
            decoration: BoxDecoration(
              borderRadius: AppRadius.large,
              border: Border.all(
                color: accent.withValues(alpha: 0.07),
                width: 18,
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: AppRadius.medium,
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    eyebrow,
                    style: const TextStyle(
                      color: Color(0xFF718078),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF68746E),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (footer != null) ...[const SizedBox(height: 18), footer!],
          ],
        ),
      ],
    ),
  );
}

class ProductSectionTitle extends StatelessWidget {
  const ProductSectionTitle({
    super.key,
    required this.title,
    required this.eyebrow,
    this.action,
  });

  final String title;
  final String eyebrow;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: Text(title, style: AppText.sectionTitle)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                eyebrow,
                style: const TextStyle(
                  color: Color(0xFF8B9790),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
      ?action,
    ],
  );
}

class ProductBadge extends StatelessWidget {
  const ProductBadge({
    super.key,
    required this.label,
    this.foreground = AppTheme.primary,
    this.background = const Color(0xFFE6F0EA),
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: background, borderRadius: AppRadius.pill),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class ProductMetric extends StatelessWidget {
  const ProductMetric({
    super.key,
    required this.value,
    required this.label,
    this.color = AppTheme.ink,
    this.background = Colors.white,
  });

  final String value;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 74),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: background,
      borderRadius: AppRadius.medium,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: AppText.caption.copyWith(color: color.withValues(alpha: 0.78)),
        ),
      ],
    ),
  );
}

class ProductNotice extends StatelessWidget {
  const ProductNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.color = AppTheme.primary,
    this.background = const Color(0xFFEAF0EB),
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: background,
      borderRadius: AppRadius.medium,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppRadius.small,
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.cardTitle.copyWith(fontSize: 14)),
              const SizedBox(height: 3),
              Text(body, style: AppText.caption),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 数据来源只使用标签表达，避免与完成状态混淆。
class SourceBadge extends StatelessWidget {
  const SourceBadge({
    super.key,
    required this.label,
    this.kind = SourceBadgeKind.service,
  });

  final String label;
  final SourceBadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final (foreground, background, icon) = switch (kind) {
      SourceBadgeKind.agent => (
        AppTheme.ai,
        const Color(0xFFECEBFF),
        Icons.auto_awesome_rounded,
      ),
      SourceBadgeKind.local => (
        AppTheme.mockBadge,
        const Color(0xFFFFF3D8),
        Icons.layers_outlined,
      ),
      SourceBadgeKind.real => (
        AppTheme.success,
        const Color(0xFFE6F0EA),
        Icons.verified_outlined,
      ),
      SourceBadgeKind.mock => (
        AppTheme.mockBadge,
        const Color(0xFFFFF3D8),
        Icons.science_outlined,
      ),
      SourceBadgeKind.unknown => (
        AppTheme.neutral,
        const Color(0xFFEDF0EE),
        Icons.help_outline_rounded,
      ),
      SourceBadgeKind.service => (
        AppTheme.primary,
        const Color(0xFFE6F0EA),
        Icons.cloud_outlined,
      ),
    };
    return ProductBadge(
      label: label,
      icon: icon,
      foreground: foreground,
      background: background,
    );
  }
}

enum SourceBadgeKind { agent, local, real, mock, unknown, service }

class SemanticStatusBadge extends StatelessWidget {
  const SemanticStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background, icon) = switch (status) {
      'completed' => (
        '已完成',
        AppTheme.success,
        const Color(0xFFE6F0EA),
        Icons.check_circle_outline_rounded,
      ),
      'cancelled' => (
        '已取消',
        AppTheme.neutral,
        const Color(0xFFEDF0EE),
        Icons.cancel_outlined,
      ),
      _ => (
        '已中断',
        AppTheme.mockBadge,
        const Color(0xFFFFF3D8),
        Icons.pause_circle_outline_rounded,
      ),
    };
    return ProductBadge(
      label: label,
      foreground: foreground,
      background: background,
      icon: icon,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _StateCard(
    icon: icon,
    title: title,
    body: body,
    color: AppTheme.primary,
    action: action,
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => _StateCard(
    icon: Icons.motion_photos_on_rounded,
    title: title,
    body: body,
    color: AppTheme.primary,
    leading: const SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _StateCard(
    icon: Icons.error_outline_rounded,
    title: title,
    body: body,
    color: AppTheme.error,
    action: action,
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    this.leading,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final Widget? leading;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading ?? Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.cardTitle),
                    const SizedBox(height: 4),
                    Text(body, style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    ),
  );
}

enum CoachFeedbackState { success, loading, error, fallback }

class CoachFeedbackCard extends StatelessWidget {
  const CoachFeedbackCard({
    super.key,
    required this.state,
    required this.title,
    required this.body,
    this.caption,
    this.onRetry,
    this.retryLabel = '重试',
  });

  final CoachFeedbackState state;
  final String title;
  final String body;
  final String? caption;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (state) {
      CoachFeedbackState.success => (
        Icons.auto_awesome_rounded,
        AppTheme.ai,
        const Color(0xFFF1F0FF),
      ),
      CoachFeedbackState.loading => (
        Icons.hourglass_top_rounded,
        AppTheme.ai,
        const Color(0xFFF1F0FF),
      ),
      CoachFeedbackState.error => (
        Icons.error_outline_rounded,
        AppTheme.error,
        const Color(0xFFFFEEE8),
      ),
      CoachFeedbackState.fallback => (
        Icons.layers_outlined,
        AppTheme.mockBadge,
        const Color(0xFFFFF8E9),
      ),
    };
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.large,
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state == CoachFeedbackState.loading)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle),
                const SizedBox(height: 5),
                Text(body, style: AppText.body),
                if (caption != null) ...[
                  const SizedBox(height: 7),
                  Text(caption!, style: AppText.caption),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(retryLabel),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.energy,
        foregroundColor: AppTheme.ink,
        minimumSize: const Size.fromHeight(52),
      ),
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : Icon(icon),
      label: Text(loading ? '请稍候…' : label),
    ),
  );
}
