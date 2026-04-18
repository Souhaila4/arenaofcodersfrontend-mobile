import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// env.dart conservé pour usage futur — token HuggingFace géré côté backend uniquement
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/models/competition_model.dart';
import 'package:arena/core/models/notification_model.dart';
import 'package:arena/core/models/wallet_model.dart';
import 'storage_service.dart';

class ApiService {
  // Singleton instance — avoids creating multiple ApiService + StorageService
  // objects in every screen.
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Base URL must match your backend (NestJS default port 3000).
  // - Android emulator: use http://10.0.2.2:3000 (localhost from emulator)
  // - iOS simulator:    http://localhost:3000
  // - Physical device:  http://<YOUR_PC_IP>:3000 (e.g. http://192.168.1.10:3000)
  static String get baseUrl {
    return 'http://192.168.1.147:3000';
  }

  final StorageService _storage = StorageService();

  // ─────────────────── AUTH ───────────────────

  /// Sign up a new user
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? githubUrl,
    String? linkedinUrl,
    required List<int> resumeBytes,
    required String resumeFilename,
    required List<int> avatarBytes,
    required String avatarFilename,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/signup');
    final request = http.MultipartRequest('POST', uri);

    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['firstName'] = firstName;
    request.fields['lastName'] = lastName;
    if (githubUrl != null && githubUrl.isNotEmpty) {
      request.fields['githubUrl'] = githubUrl;
    }
    if (linkedinUrl != null && linkedinUrl.isNotEmpty) {
      request.fields['linkedinUrl'] = linkedinUrl;
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'resume',
        resumeBytes,
        filename: resumeFilename,
      ),
    );
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'avatar',
        avatarBytes,
        filename: avatarFilename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 201) {
      throw _handleError(response);
    }
  }

  /// Sign in an existing user
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
      await _storage.saveToken(authResponse.tokens.accessToken);
      await _storage.saveUser(authResponse.user);
      return authResponse;
    } else {
      throw _handleError(response);
    }
  }

  /// Verify email with 6-digit code
  Future<AuthResponse> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
      }),
    );

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
      await _storage.saveToken(authResponse.tokens.accessToken);
      await _storage.saveUser(authResponse.user);
      return authResponse;
    } else {
      throw _handleError(response);
    }
  }

  /// Resend verification code
  Future<void> resendVerification({required String email}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/resend-verification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  /// Request password reset email
  Future<void> forgotPassword({required String email}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  /// Reset password using code
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  /// Get current user profile (protected)
  Future<AuthUser> getMe() async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final user = AuthUser.fromJson(jsonDecode(response.body));
      await _storage.saveUser(user);
      return user;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Get a generic public user profile
  Future<AuthUser> getPublicUser(String id) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/user/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return AuthUser.fromJson(jsonDecode(response.body));
    } else {
      throw _handleError(response);
    }
  }

  /// Update user profile (protected)
  Future<AuthUser> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? mainSpecialty,
    String? githubUrl,
    String? linkedinUrl,
  }) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (email != null) body['email'] = email;
    if (mainSpecialty != null) body['mainSpecialty'] = mainSpecialty;
    if (githubUrl != null) body['githubUrl'] = githubUrl;
    if (linkedinUrl != null) body['linkedinUrl'] = linkedinUrl;

    final response = await http.patch(
      Uri.parse('$baseUrl/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final user = AuthUser.fromJson(jsonDecode(response.body));
      await _storage.saveUser(user);
      return user;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Update the current user's avatar
  Future<AuthUser> updateAvatar(File imageFile) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Unauthenticated');

    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/auth/profile/avatar'));
    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      await http.MultipartFile.fromPath(
        'avatar',
        imageFile.path,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final user = AuthUser.fromJson(jsonDecode(response.body));
      await _storage.saveUser(user);
      return user;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Sign out (clears local storage)
  Future<void> signOut() async {
    await _storage.clearAll();
  }

  /// Get Leaderboard (Real users filtered by specialty)
  Future<List<AuthUser>> getLeaderboard({String? specialty}) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    var uriStr = '$baseUrl/user/leaderboard';
    if (specialty != null && specialty != 'All') {
      uriStr += '?specialty=$specialty';
    }

    final response = await http.get(
      Uri.parse(uriStr),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => AuthUser.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  // ─────────────────── COMPETITIONS (HACKATHONS) ───────────────────

  /// List hackathons for the current user (matches mainSpecialty)
  Future<CompetitionsResponse> getCompetitionsForMe({
    int page = 1,
    int limit = 20,
    String? status,
    String? difficulty,
    bool? onlyActive,
  }) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final q = <String>['page=$page', 'limit=$limit'];
    if (status != null) q.add('status=$status');
    if (difficulty != null) q.add('difficulty=$difficulty');
    if (onlyActive != null) q.add('onlyActive=$onlyActive');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/for-me?${q.join('&')}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return CompetitionsResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }
  /// Get competitions won by the logged in user
  Future<CompetitionsResponse> getMyWins() async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/my-wins'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return CompetitionsResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// List all competitions (optional filters)
  Future<CompetitionsResponse> getCompetitions({
    int page = 1,
    int limit = 20,
    String? status,
    String? difficulty,
    String? specialty,
    bool? onlyActive,
  }) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final q = <String>['page=$page', 'limit=$limit'];
    if (status != null) q.add('status=$status');
    if (difficulty != null) q.add('difficulty=$difficulty');
    if (specialty != null) q.add('specialty=$specialty');
    if (onlyActive != null) q.add('onlyActive=$onlyActive');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions?${q.join('&')}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return CompetitionsResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Get hackathon ideas from AI (Admin only). Use when creating a new hackathon.
  Future<List<HackathonIdea>> getHackathonIdeas() async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/hackathon-ideas'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final list = json['ideas'] as List<dynamic>? ?? [];
      return list.map((e) => HackathonIdea.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Get a single competition by ID
  Future<Competition> getCompetitionById(String id) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return Competition.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Join a competition (USER role) + Take a specific face picture for anti-cheat
  Future<void> joinCompetition(String competitionId, File faceImage) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/competitions/$competitionId/join'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      await http.MultipartFile.fromPath('hackathonFaceImage', faceImage.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) return;
    if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    }
    throw _handleError(response);
  }

  /// Check if the current user has joined a specific competition
  Future<bool> checkMyParticipation(String competitionId) async {
    final token = await _storage.getToken();
    if (token == null) return false;

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/$competitionId/my-participation'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  }

  /// Get full participation details (status, githubUrl, score, etc.)
  Future<Map<String, dynamic>?> getParticipationDetails(String competitionId) async {
    final token = await _storage.getToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/$competitionId/my-participation'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  /// Submit GitHub link for a competition (anti-cheat check)
  Future<Map<String, dynamic>> submitGithubLink(String competitionId, String githubUrl) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/competitions/$competitionId/submit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'githubUrl': githubUrl}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  // ─────────────────── ANTI-CHEAT ───────────────────
  // Les appels IA sont proxifiés via le backend NestJS.
  // Le token HuggingFace reste exclusivement dans le .env du serveur.
  // Les modèles HF privés prennent 30-45s à répondre (+ cold start).

  /// Validate Workspace Image — proxied via NestJS backend
  /// Timeout étendu à 120s pour accommoder les modèles IA privés.
  Future<Map<String, dynamic>> validateWorkspaceImage(
      List<int> workspaceBytes, String workspaceFilename,
      {List<int>? avatarBytes, String? avatarFilename}) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final uri = Uri.parse('$baseUrl/anti-cheat/validate-image');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(http.MultipartFile.fromBytes(
      'image', workspaceBytes,
      filename: workspaceFilename,
      contentType: MediaType('image', 'jpeg'),
    ));

    if (avatarBytes != null && avatarFilename != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'avatar', avatarBytes,
        filename: avatarFilename,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    // Timeout étendu (120s) pour les modèles IA qui prennent 30-45s
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        throw ApiError(
          statusCode: 408,
          message: 'Le modèle IA Image met trop de temps à répondre. Réessayez.',
        );
      },
    );
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      // Essayer d'extraire le message d'erreur du backend
      String errorMsg = 'AI Image Validation failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) errorMsg = body['message'].toString();
      } catch (_) {}
      throw ApiError(statusCode: response.statusCode, message: errorMsg);
    }
  }

  /// Validate Audio — proxied via NestJS backend
  /// Timeout étendu à 120s pour accommoder les modèles IA privés.
  Future<Map<String, dynamic>> validateVocalAudio(
      List<int> audioBytes, String audioFilename) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final uri = Uri.parse('$baseUrl/anti-cheat/validate-audio');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(http.MultipartFile.fromBytes(
      'audio', audioBytes,
      filename: audioFilename,
      contentType: MediaType('audio', 'm4a'),
    ));

    // Utiliser un timeout étendu (120s) pour les modèles IA
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        throw ApiError(
          statusCode: 408,
          message: 'Le modèle IA Vocal met trop de temps à répondre. Réessayez.',
        );
      },
    );
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw ApiError(
            statusCode: response.statusCode,
            message: 'Invalid AI JSON Response');
      }
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      // Essayer d'extraire le message d'erreur du backend
      String errorMsg = 'AI Vocal Validation failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) errorMsg = body['message'].toString();
      } catch (_) {}
      throw ApiError(statusCode: response.statusCode, message: errorMsg);
    }
  }

  // ─────────────────── CHECKPOINTS ───────────────────

  /// List checkpoints for a competition
  Future<List<CompetitionCheckpoint>> getCompetitionCheckpoints(String competitionId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/$competitionId/checkpoints'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((e) => CompetitionCheckpoint.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Get current user's checkpoint submissions for a competition
  Future<List<CheckpointSubmissionWithCheckpoint>> getMyCheckpointSubmissions(String competitionId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/$competitionId/my-checkpoint-submissions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((e) => CheckpointSubmissionWithCheckpoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Submit a checkpoint (proof URL and optional notes)
  Future<Map<String, dynamic>> submitCheckpoint({
    required String competitionId,
    required String checkpointId,
    required String proofUrl,
    String? notes,
  }) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final body = <String, dynamic>{'proofUrl': proofUrl};
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

    final response = await http.patch(
      Uri.parse('$baseUrl/competitions/$competitionId/checkpoints/$checkpointId/submit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Create a competition (ADMIN only)
  ///
  /// Get all participants of a competition (for admin view — old endpoint)
  Future<Map<String, dynamic>> getCompetitionParticipants(String competitionId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/$competitionId/participants'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Get ALL participants for admin (includes DISQUALIFIED with reasons)
  Future<Map<String, dynamic>> getAllParticipantsAdmin(String competitionId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/$competitionId/participants/all'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Get Top N participants sorted by AI score (with scoringReport)
  Future<Map<String, dynamic>> getTopParticipantsAdmin(String competitionId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/$competitionId/top-participants'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Select a winner for a hackathon (admin/company only)
  Future<Map<String, dynamic>> selectWinner(String competitionId, String participantId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/competitions/$competitionId/winner/$participantId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Create a competition (ADMIN only)
  Future<Competition> createCompetition({
    required String title,
    required String description,
    required String difficulty,
    String? specialty,
    required String startDate,
    required String endDate,
    double rewardPool = 0,
    int? maxParticipants,
    bool antiCheatEnabled = false,
    double? antiCheatThreshold,
    int? topN,
  }) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'difficulty': difficulty,
      'startDate': startDate,
      'endDate': endDate,
      'rewardPool': rewardPool,
      'antiCheatEnabled': antiCheatEnabled,
    };
    if (specialty != null) body['specialty'] = specialty;
    if (maxParticipants != null) body['maxParticipants'] = maxParticipants;
    if (antiCheatThreshold != null) body['antiCheatThreshold'] = antiCheatThreshold;
    if (topN != null) body['topN'] = topN;

    final response = await http.post(
      Uri.parse('$baseUrl/competitions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      return Competition.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  // ─────────────────── NOTIFICATIONS ───────────────────

  /// List my notifications
  Future<NotificationsResponse> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final q = <String>['limit=$limit'];
    q.add('unreadOnly=$unreadOnly');

    final response = await http.get(
      Uri.parse('$baseUrl/notifications?${q.join('&')}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return NotificationsResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Mark one notification as read
  Future<void> markNotificationRead(String notificationId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.patch(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) return;
    if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    }
    throw _handleError(response);
  }

  /// Mark all notifications as read
  Future<NotificationsResponse> markAllNotificationsRead() async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.patch(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return NotificationsResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  // ─────────────────── LEADERBOARD ───────────────────

  /// Get Global Leaderboard (all users ranked by totalWins)
  Future<Map<String, dynamic>> getGlobalLeaderboard({int limit = 20}) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/leaderboard/global?limit=$limit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Get Leaderboard for a specific Hackathon
  Future<Map<String, dynamic>> getCompetitionLeaderboard(String competitionId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/competitions/$competitionId/leaderboard'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  // ─────────────────── STREAM (CHAT & VIDEO) ───────────────────

  /// Get Stream User Token
  Future<Map<String, dynamic>> getStreamToken({String? userId}) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/stream/token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: userId != null ? jsonEncode({'userId': userId}) : jsonEncode({}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Get list of Hackathon Rooms based on specialty
  Future<List<dynamic>> getStreamRooms() async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/stream/rooms'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['rooms'] as List<dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Join a Stream Room
  Future<void> joinStreamRoom(String roomId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/stream/room/$roomId/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Join general Arena live channel
  Future<void> joinArenaLive() async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/stream/arena/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  // ─────────────────── EQUIPE (TEAM) MANAGEMENT ───────────────────

  /// Create a new team for a competition (leader becomes first member)
  Future<Map<String, dynamic>> createEquipe({
    required String name,
    required String competitionId,
  }) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/equipes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'competitionId': competitionId,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Get my team for a specific competition (returns null if not in a team)
  Future<Map<String, dynamic>?> getMyEquipe(String competitionId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/equipes/my-equipe/$competitionId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = response.body.trim();
      if (body.isEmpty || body == 'null') return null;
      return jsonDecode(body) as Map<String, dynamic>?;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Get equipe details by ID
  Future<Map<String, dynamic>> getEquipeById(String equipeId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/equipes/$equipeId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Search users to invite to a team (by name or email)
  Future<List<Map<String, dynamic>>> searchUsersForTeam(String query, {String? competitionId}) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final q = <String>['query=$query'];
    if (competitionId != null) q.add('competitionId=$competitionId');

    final response = await http.get(
      Uri.parse('$baseUrl/equipes/search-users?${q.join('&')}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Invite a user to your team (leader only) by email
  Future<Map<String, dynamic>> inviteToEquipe(String equipeId, String email) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/equipes/$equipeId/invite'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Get my pending team invitations
  Future<Map<String, dynamic>> getMyInvitations() async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/equipe-invitations/my-invitations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Accept a team invitation
  Future<Map<String, dynamic>> acceptInvitation(String invitationId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/equipe-invitations/$invitationId/accept'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Decline a team invitation
  Future<Map<String, dynamic>> declineInvitation(String invitationId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/equipe-invitations/$invitationId/decline'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Mark team as ready (leader only, max 3 members)
  Future<Map<String, dynamic>> markTeamReady(String equipeId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/equipes/$equipeId/mark-ready'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Join team chat channel (Stream)
  Future<void> joinTeamChat(String equipeId, String competitionId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/stream/team/$equipeId/comp/$competitionId/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  // ─────────────────── PUSH NOTIFICATIONS ───────────────────

  /// Register FCM token with the backend
  Future<void> registerFcmToken(String fcmToken) async {
    final token = await _storage.getToken();
    if (token == null) return;

    await http.post(
      Uri.parse('$baseUrl/auth/fcm-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'fcmToken': fcmToken}),
    );
  }

  // ─────────────────── ROLES & ADMIN ───────────────────

  /// Request company role
  Future<void> requestCompanyRole(String companyName, {String? description}) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/user/request-company-role'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'companyName': companyName,
        if (description != null) 'description': description,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return;
    } else {
      throw _handleError(response);
    }
  }

  /// Get company requests (Admin only)
  Future<List<dynamic>> getCompanyRequests({String? status}) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final uri = Uri.parse('$baseUrl/admin/company-requests').replace(
      queryParameters: status != null ? {'status': status} : null,
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw _handleError(response);
    }
  }

  /// Review company request (Admin only)
  Future<void> reviewCompanyRequest(String requestId, String status) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.patch(
      Uri.parse('$baseUrl/admin/company-requests/$requestId/review'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode == 200) {
      return;
    } else {
      throw _handleError(response);
    }
  }

  // ─────────────────── WALLET (Arena Coin) ───────────────────

  /// Get current user's Arena Coin wallet info + transaction history
  Future<WalletInfo> getMyWallet() async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/wallet/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return WalletInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  /// Register (or update) the current user's Hedera account ID
  Future<void> registerWallet(String hederaAccountId) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.patch(
      Uri.parse('$baseUrl/user/wallet'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'hederaAccountId': hederaAccountId}),
    );

    if (response.statusCode == 200) return;
    if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    }
    throw _handleError(response);
  }

  /// Generate a certificate NFT for a hackathon the current user won
  Future<Map<String, dynamic>> generateCertificate(String hackathonName) async {
    final token = await _storage.getToken();
    if (token == null) throw ApiError(statusCode: 401, message: 'Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/certificate/generate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'hackathonName': hackathonName}),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      await _storage.clearAll();
      throw ApiError(statusCode: 401, message: 'Session expired');
    } else {
      throw _handleError(response);
    }
  }

  // ─────────────────── HELPERS ───────────────────

  ApiError _handleError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return ApiError.fromJson(body);
    } catch (_) {
      return ApiError(
        statusCode: response.statusCode,
        message: 'An unexpected error occurred',
      );
    }
  }
}
