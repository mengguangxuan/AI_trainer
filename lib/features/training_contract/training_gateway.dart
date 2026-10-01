import 'package:flutter/widgets.dart';

import '../../core/models/session_result.dart';
import '../../core/models/training_launch_args.dart';

/// C implements this bridge; D never imports the real training module.
abstract class TrainingGateway {
  Future<SessionResult?> start(
    BuildContext context,
    TrainingLaunchArgs args,
  );
}
