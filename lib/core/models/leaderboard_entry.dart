/// Represents one entry in the live leaderboard with movement metadata.
class LeaderboardEntry {
  final int rank;
  final int previousRank;

  /// 'up', 'down', 'same', or 'new'
  final String movement;
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? mainSpecialty;
  final String role;
  final int totalWins;
  final int totalChallenges;
  final int winRate;

  LeaderboardEntry({
    required this.rank,
    required this.previousRank,
    required this.movement,
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.mainSpecialty,
    this.role = 'USER',
    this.totalWins = 0,
    this.totalChallenges = 0,
    this.winRate = 0,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int? ?? 0,
      previousRank: json['previousRank'] as int? ?? json['rank'] as int? ?? 0,
      movement: json['movement'] as String? ?? 'same',
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      mainSpecialty: json['mainSpecialty'] as String?,
      role: json['role'] as String? ?? 'USER',
      totalWins: json['totalWins'] as int? ?? 0,
      totalChallenges: json['totalChallenges'] as int? ?? 0,
      winRate: json['winRate'] as int? ?? 0,
    );
  }

  /// How many ranks this entry moved (positive = climbed up).
  int get rankDelta => previousRank - rank;

  bool get movedUp => movement == 'up';
  bool get movedDown => movement == 'down';
  bool get isNew => movement == 'new';
}

/// Payload from one SSE leaderboard event.
class LeaderboardUpdate {
  final String timestamp;
  final int totalUsers;
  final List<LeaderboardEntry> leaderboard;

  LeaderboardUpdate({
    required this.timestamp,
    required this.totalUsers,
    required this.leaderboard,
  });

  factory LeaderboardUpdate.fromJson(Map<String, dynamic> json) {
    final list = json['leaderboard'] as List<dynamic>? ?? [];
    return LeaderboardUpdate(
      timestamp: json['timestamp'] as String? ?? '',
      totalUsers: json['totalUsers'] as int? ?? 0,
      leaderboard: list
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
