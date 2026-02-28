class GithubRepo {
  final String name;
  final String url;
  final int stars;
  final String? language;

  GithubRepo({
    required this.name,
    required this.url,
    required this.stars,
    this.language,
  });

  factory GithubRepo.fromJson(Map<String, dynamic> json) => GithubRepo(
        name: json['name'] as String,
        url: json['url'] as String,
        stars: json['stars'] as int? ?? 0,
        language: json['language'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'stars': stars,
        if (language != null) 'language': language,
      };
}

class AuthUser {
  final String id;
  final String email;
  final String role;
  final String firstName;
  final String lastName;
  final String? mainSpecialty;
  final int totalWins;
  final int totalChallenges;
  final double walletBalance;
  final String? avatarUrl;
  final List<String> skillTags;
  final String? githubUrl;
  final String? linkedinUrl;
  final List<GithubRepo> githubRepos;

  AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.mainSpecialty,
    this.totalWins = 0,
    this.totalChallenges = 0,
    this.walletBalance = 0.0,
    this.avatarUrl,
    this.skillTags = const [],
    this.githubUrl,
    this.linkedinUrl,
    this.githubRepos = const [],
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: (json['email'] as String?) ?? '',
        role: (json['role'] as String?) ?? 'USER',
        firstName: (json['firstName'] as String?) ?? '',
        lastName: (json['lastName'] as String?) ?? '',
        mainSpecialty: json['mainSpecialty'] as String?,
        totalWins: json['totalWins'] as int? ?? 0,
        totalChallenges: json['totalChallenges'] as int? ?? 0,
        walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
        avatarUrl: json['avatarUrl'] as String?,
        skillTags: (json['skillTags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        githubUrl: json['githubUrl'] as String?,
        linkedinUrl: json['linkedinUrl'] as String?,
        githubRepos: (json['githubRepos'] as List<dynamic>?)
                ?.map((e) => GithubRepo.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'firstName': firstName,
        'lastName': lastName,
        if (mainSpecialty != null) 'mainSpecialty': mainSpecialty,
        'totalWins': totalWins,
        'totalChallenges': totalChallenges,
        'walletBalance': walletBalance,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'skillTags': skillTags,
        if (githubUrl != null) 'githubUrl': githubUrl,
        if (linkedinUrl != null) 'linkedinUrl': linkedinUrl,
        'githubRepos': githubRepos.map((e) => e.toJson()).toList(),
      };

  AuthUser copyWith({
    String? id,
    String? email,
    String? role,
    String? firstName,
    String? lastName,
    String? mainSpecialty,
    int? totalWins,
    int? totalChallenges,
    double? walletBalance,
    String? avatarUrl,
    List<String>? skillTags,
    String? githubUrl,
    String? linkedinUrl,
    List<GithubRepo>? githubRepos,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      mainSpecialty: mainSpecialty ?? this.mainSpecialty,
      totalWins: totalWins ?? this.totalWins,
      totalChallenges: totalChallenges ?? this.totalChallenges,
      walletBalance: walletBalance ?? this.walletBalance,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      skillTags: skillTags ?? this.skillTags,
      githubUrl: githubUrl ?? this.githubUrl,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      githubRepos: githubRepos ?? this.githubRepos,
    );
  }
}

class AuthTokens {
  final String accessToken;
  final int expiresIn;

  AuthTokens({required this.accessToken, required this.expiresIn});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        expiresIn: json['expiresIn'] as int,
      );
}

class AuthResponse {
  final AuthUser user;
  final AuthTokens tokens;

  AuthResponse({required this.user, required this.tokens});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
        tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
      );
}

/// Represents an API error response from the backend
class ApiError {
  final int statusCode;
  final dynamic message; // Can be String or List<String>
  final String? error;

  ApiError({required this.statusCode, required this.message, this.error});

  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
        statusCode: json['statusCode'] as int,
        message: json['message'],
        error: json['error'] as String?,
      );

  /// Returns a user-friendly error message
  String get displayMessage {
    if (message is List) {
      return (message as List).join('\n');
    }
    return message.toString();
  }
}
