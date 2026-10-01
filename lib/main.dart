import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'features/product/data/local_product_repository.dart';
import 'features/product/data/template_coach_repository.dart';
import 'features/product/domain/product_controller.dart';
import 'features/product/presentation/product_shell.dart';
import 'features/training_contract/native_training_gateway.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = ProductController(
    LocalProductRepository(SharedPreferencesAsync()),
    TemplateCoachRepository(),
  );
  runApp(DStarterApp(controller: controller));
}

class DStarterApp extends StatelessWidget {
  const DStarterApp({super.key, required this.controller});

  final ProductController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '动姿智护 D 模块原型',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: ProductShell(
          controller: controller,
          training: NativeTrainingGateway(),
        ),
      );
}
