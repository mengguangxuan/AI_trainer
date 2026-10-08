import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/product_controller.dart';
import 'product_ui.dart';

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key, required this.controller});

  final ProductController controller;

  @override
  Widget build(BuildContext context) {
    final advice = controller.nutrition!;
    final sourceLabel = advice.source == 'agent'
        ? 'AI 建议'
        : controller.nutritionUsingFallback
        ? '本地模板'
        : '服务规则';

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        ProductHero(
          eyebrow: 'DAILY FUEL · 今日补给',
          title: '吃得均衡，练得稳定',
          subtitle: '围绕你的训练目标提供一般饮食提示，不追求复杂计算。',
          icon: Icons.restaurant_menu_rounded,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7B5015), Color(0xFFAA7017), Color(0xFFC88B2A)],
          ),
          footer: ProductBadge(
            label: sourceLabel,
            icon: advice.source == 'agent'
                ? Icons.auto_awesome_rounded
                : Icons.layers_outlined,
            foreground: Colors.white,
            background: const Color(0x28FFFFFF),
          ),
        ),
        const SizedBox(height: 20),
        const ProductSectionTitle(title: '今日建议', eyebrow: 'RECOMMENDATION'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      color: const Color(0xFFFFF1D2),
                      child: const Icon(
                        Icons.ramen_dining_rounded,
                        color: Color(0xFFAA7017),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(advice.title, style: AppText.cardTitle),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  color: const Color(0xFFFFF8E9),
                  child: Text(advice.body, style: AppText.body),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const ProductSectionTitle(title: '建议边界', eyebrow: 'SAFE GUIDANCE'),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(
              child: ProductMetric(
                value: '一般',
                label: '建议范围',
                color: AppTheme.primary,
                background: Color(0xFFEAF0EB),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ProductMetric(
                value: '不做',
                label: '精确热量',
                color: Color(0xFFAA7017),
                background: Color(0xFFFFF3D8),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ProductMetric(
                value: '不替代',
                label: '医疗意见',
                color: AppTheme.ai,
                background: Color(0xFFECEBFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const ProductNotice(
          icon: Icons.health_and_safety_outlined,
          title: '饮食安全说明',
          body: '本页面不计算热量，也不提供疾病、过敏或补剂治疗的个体化医疗建议。',
          color: Color(0xFFAA7017),
          background: Color(0xFFFFF3D8),
        ),
      ],
    );
  }
}
