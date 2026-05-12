/// Model for the AI Team Synergy Predictor response.
class TeamSynergy {
  final String equipeId;
  final String equipeName;
  final int memberCount;
  final int synergyScore;
  final List<SynergyAxis> axes;
  final List<SynergyAxis> strengths;
  final List<SynergyAxis> weaknesses;
  final String advice;
  final String? targetTheme;
  final String? targetAxis;

  TeamSynergy({
    required this.equipeId,
    required this.equipeName,
    required this.memberCount,
    required this.synergyScore,
    required this.axes,
    required this.strengths,
    required this.weaknesses,
    required this.advice,
    this.targetTheme,
    this.targetAxis,
  });

  factory TeamSynergy.fromJson(Map<String, dynamic> json) {
    return TeamSynergy(
      equipeId: json['equipeId'] as String? ?? '',
      equipeName: json['equipeName'] as String? ?? '',
      memberCount: json['memberCount'] as int? ?? 0,
      synergyScore: json['synergyScore'] as int? ?? 0,
      axes: (json['axes'] as List<dynamic>? ?? [])
          .map((e) => SynergyAxis.fromJson(e as Map<String, dynamic>))
          .toList(),
      strengths: (json['strengths'] as List<dynamic>? ?? [])
          .map((e) => SynergyAxis.fromJson(e as Map<String, dynamic>))
          .toList(),
      weaknesses: (json['weaknesses'] as List<dynamic>? ?? [])
          .map((e) => SynergyAxis.fromJson(e as Map<String, dynamic>))
          .toList(),
      advice: json['advice'] as String? ?? '',
      targetTheme: json['targetTheme'] as String?,
      targetAxis: json['targetAxis'] as String?,
    );
  }
}

class SynergyAxis {
  final String name;
  final int score;

  SynergyAxis({required this.name, required this.score});

  factory SynergyAxis.fromJson(Map<String, dynamic> json) {
    return SynergyAxis(
      name: json['name'] as String? ?? '',
      score: json['score'] as int? ?? 0,
    );
  }
}
