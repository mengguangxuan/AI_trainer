/// Reference token catalog used by the local demo adapter. A production
/// TeleAI/智传网 adapter should replace these values with provider-issued
/// session-scoped opaque tokens.
class EdgePrivacyTokenCatalog {
  static const actionSquat =
      'pt1_c1c9a36a4b98bc4beabbd846eec8a5151117befe';
  static const actionPushUp =
      'pt1_5e09fbd3cad4082b452316088ec8718c271a1468';
  static const phaseDown =
      'pt1_3d1eaeac08bf62672cb5c00938ac9a585728e1e4';
  static const phaseBottom =
      'pt1_a56e079bb9ffad9c93777f136502c19f7dd19ebf';
  static const phaseUp =
      'pt1_8ef9c9b8da7275eae83d3827ab21e66e62cf0560';
  static const expressionFocused =
      'pt1_1b67c76004d8190485de5b92315713c2d2a0625a';
  static const stateOccluded =
      'pt1_c23d62b42cdadb712bd4d4efaede6a07f434eaf3';
  static const safetyStop =
      'pt1_17bcadaa908e982b942a40fee751bc61f79f7c26';

  const EdgePrivacyTokenCatalog._();
}

class PrivacyToken {
  const PrivacyToken({
    required this.kind,
    required this.value,
    required this.confidence,
    this.atMs,
  });

  final String kind;
  final String value;
  final double confidence;
  final int? atMs;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'value': value,
    'confidence': confidence,
    if (atMs != null) 'at_ms': atMs,
  };
}

/// Data emitted by the local perception adapters. It intentionally has no
/// media, pixels, raw landmarks, or raw URDF fields.
class PrivacyFlowRequest {
  const PrivacyFlowRequest({
    required this.flowId,
    required this.sessionId,
    required this.exerciseId,
    required this.startedAt,
    required this.finishedAt,
    required this.provider,
    required this.algorithm,
    required this.videoModelVersion,
    required this.videoTokens,
    required this.skeletonProvider,
    required this.skeletonModelVersion,
    required this.urdfToken,
    required this.trajectoryToken,
    required this.jointCount,
    required this.frameCount,
    required this.durationMs,
    required this.stateTokens,
  });

  final String flowId;
  final String sessionId;
  final String exerciseId;
  final String startedAt;
  final String finishedAt;
  final String provider;
  final String algorithm;
  final String videoModelVersion;
  final List<PrivacyToken> videoTokens;
  final String skeletonProvider;
  final String skeletonModelVersion;
  final String urdfToken;
  final String trajectoryToken;
  final int jointCount;
  final int frameCount;
  final int durationMs;
  final List<PrivacyToken> stateTokens;

  Map<String, Object?> toJson() => {
    'contract': 'app_privacy_flow_v1',
    'schema_version': 1,
    'flow_id': flowId,
    'session_id': sessionId,
    'exercise_id': exerciseId,
    'started_at': startedAt,
    'finished_at': finishedAt,
    'privacy': {
      'transport': 'token_only',
      'provider': provider,
      'algorithm': algorithm,
      'key_scope': 'session',
      'raw_media_uploaded': false,
      'raw_media_retained': false,
      'user_consented': true,
    },
    'video_llm': {
      'provider': 'edge_vlm_adapter',
      'model_version': videoModelVersion,
      'tokens': videoTokens.map((token) => token.toJson()).toList(),
    },
    'skeleton': {
      'provider': skeletonProvider,
      'model_version': skeletonModelVersion,
      'urdf_token': urdfToken,
      'trajectory_token': trajectoryToken,
      'joint_count': jointCount,
      'frame_count': frameCount,
      'duration_ms': durationMs,
      'coordinate_frame': 'body_normalized',
    },
    'complex_state': {
      'tokens': stateTokens.map((token) => token.toJson()).toList(),
    },
  };
}

class PrivacyFlowResult {
  const PrivacyFlowResult({
    required this.flowId,
    required this.sessionId,
    required this.status,
    required this.privacy,
    required this.analysis,
    required this.overlay,
    required this.coach,
  });

  final String flowId;
  final String sessionId;
  final String status;
  final Map<String, dynamic> privacy;
  final Map<String, dynamic> analysis;
  final Map<String, dynamic> overlay;
  final Map<String, dynamic> coach;

  factory PrivacyFlowResult.fromJson(Map<String, dynamic> json) {
    if (json['contract'] != 'app_privacy_flow_v1' ||
        json['schema_version'] != 1 ||
        json['privacy'] is! Map<String, dynamic> ||
        (json['privacy'] as Map<String, dynamic>)['token_only'] != true ||
        (json['privacy'] as Map<String, dynamic>)['raw_video_received'] !=
            false ||
        json['analysis'] is! Map<String, dynamic> ||
        json['overlay'] is! Map<String, dynamic> ||
        (json['overlay'] as Map<String, dynamic>)['available'] != true ||
        json['coach'] is! Map<String, dynamic>) {
      throw const FormatException('incompatible privacy flow response');
    }
    try {
      return PrivacyFlowResult(
        flowId: json['flow_id'] as String,
        sessionId: json['session_id'] as String,
        status: json['status'] as String,
        privacy: (json['privacy'] as Map).cast<String, dynamic>(),
        analysis: (json['analysis'] as Map).cast<String, dynamic>(),
        overlay: (json['overlay'] as Map).cast<String, dynamic>(),
        coach: (json['coach'] as Map).cast<String, dynamic>(),
      );
    } on TypeError {
      throw const FormatException('invalid privacy flow response');
    }
  }
}
