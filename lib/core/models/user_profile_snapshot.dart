class UserProfileSnapshot {
  const UserProfileSnapshot({
    required this.goal,
    required this.experience,
    required this.daysPerWeek,
    required this.minutesPerSession,
    required this.hasEquipment,
    required this.hasCurrentDiscomfort,
    required this.dietPreference,
  });

  final String goal;
  final String experience;
  final int daysPerWeek;
  final int minutesPerSession;
  final bool hasEquipment;
  final bool hasCurrentDiscomfort;
  final String dietPreference;

  Map<String, Object?> toJson() => {
        'schema_version': 1,
        'goal': goal,
        'experience': experience,
        'days_per_week': daysPerWeek,
        'minutes_per_session': minutesPerSession,
        'has_equipment': hasEquipment,
        'has_current_discomfort': hasCurrentDiscomfort,
        'diet_preference': dietPreference,
      };

  factory UserProfileSnapshot.fromJson(Map<String, dynamic> json) =>
      UserProfileSnapshot(
        goal: json['goal'] as String? ?? '建立运动习惯',
        experience: json['experience'] as String? ?? '新手',
        daysPerWeek: (json['days_per_week'] as num?)?.toInt() ?? 2,
        minutesPerSession:
            (json['minutes_per_session'] as num?)?.toInt() ?? 15,
        hasEquipment: json['has_equipment'] as bool? ?? false,
        hasCurrentDiscomfort:
            json['has_current_discomfort'] as bool? ?? false,
        dietPreference: json['diet_preference'] as String? ?? '无特别偏好',
      );
}
