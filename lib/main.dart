import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/models/agent_connection.dart';
import 'features/product/data/local_product_repository.dart';
import 'features/product/data/agent_coach_repository.dart';
import 'features/product/data/agent_chat_repository.dart';
import 'features/product/domain/product_controller.dart';
import 'features/product/presentation/product_shell.dart';
import 'features/training_contract/native_training_gateway.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Android emulator/USB development uses adb reverse to reach the Agent service.
  const agentBaseUrl = String.fromEnvironment(
    'AGENT_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/app/v1/',
  );
  const agentDevToken = String.fromEnvironment('AGENT_DEV_TOKEN');
  final controller = ProductController(
    LocalProductRepository(SharedPreferencesAsync()),
    AgentCoachRepository(
      baseUrl: Uri.parse(agentBaseUrl),
      devToken: agentDevToken.isEmpty ? null : agentDevToken,
    ),
    chat: AgentChatRepository(
      appBaseUrl: Uri.parse(agentBaseUrl),
      devToken: agentDevToken.isEmpty ? null : agentDevToken,
    ),
    initialConnection: const AgentConnection(
      baseUrl: agentBaseUrl,
      devToken: agentDevToken,
    ),
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
