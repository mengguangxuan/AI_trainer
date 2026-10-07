class AgentConnection {
  const AgentConnection({
    this.baseUrl = 'http://127.0.0.1:8000/api/app/v1/',
    this.devToken = '',
    this.allowDataUpload = false,
  });

  final String baseUrl;
  final String devToken;
  final bool allowDataUpload;

  factory AgentConnection.fromJson(Map<String, dynamic> json) =>
      AgentConnection(
        baseUrl: json['base_url'] as String,
        devToken: json['dev_token'] as String? ?? '',
        allowDataUpload: json['allow_data_upload'] == true,
      );

  Map<String, Object?> toJson() => {
    'base_url': baseUrl,
    'dev_token': devToken,
    'allow_data_upload': allowDataUpload,
  };
}
