import 'package:arena/core/models/auth_models.dart';

/// Résultat du matching IA entre une offre et un candidat.
class JobMatch {
  final String id;
  final String jobId;
  final String userId;
  final int score;
  final String reason;
  final int rank;
  final AuthUser? user;
  final DateTime createdAt;

  const JobMatch({
    required this.id,
    required this.jobId,
    required this.userId,
    required this.score,
    required this.reason,
    required this.rank,
    this.user,
    required this.createdAt,
  });

  factory JobMatch.fromJson(Map<String, dynamic> json) => JobMatch(
        id: json['id'] as String,
        jobId: json['jobId'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        score: json['score'] as int? ?? 0,
        reason: json['reason'] as String? ?? '',
        rank: json['rank'] as int? ?? 0,
        user: json['user'] != null
            ? AuthUser.fromJson(json['user'] as Map<String, dynamic>)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

/// Réponse du endpoint GET /jobs/:id/matches
class JobMatchesResponse {
  final Map<String, dynamic> job;
  final int totalMatches;
  final List<JobMatch> matches;

  const JobMatchesResponse({
    required this.job,
    required this.totalMatches,
    required this.matches,
  });

  factory JobMatchesResponse.fromJson(Map<String, dynamic> json) =>
      JobMatchesResponse(
        job: json['job'] as Map<String, dynamic>? ?? {},
        totalMatches: json['totalMatches'] as int? ?? 0,
        matches: (json['matches'] as List<dynamic>?)
                ?.map((e) => JobMatch.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
