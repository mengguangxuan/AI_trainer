import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ProductHero extends StatelessWidget {
  const ProductHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.gradient = AppTheme.heroGradient,
    this.footer,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: gradient),
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
              border: Border.all(color: const Color(0x1FFFFFFF), width: 18),
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
                  color: const Color(0x24FFFFFF),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    eyebrow,
                    style: const TextStyle(
                      color: Color(0xFFD4E3DC),
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
                color: Colors.white,
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
                color: Color(0xFFE2EDE8),
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
    color: background,
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
    color: background,
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
    color: background,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          color: color.withValues(alpha: 0.12),
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
