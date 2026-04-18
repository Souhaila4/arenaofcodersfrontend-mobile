import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:arena/core/models/competition_model.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/features/hackathons/screens/submit_checkpoint_screen.dart';
import 'package:arena/features/profile/screens/public_profile_screen.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream;
import 'package:arena/features/chat/screens/chat_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'admin_participants_screen.dart';

class HackathonDetailScreen extends StatefulWidget {
  final String competitionId;

  const HackathonDetailScreen({super.key, required this.competitionId});

  @override
  State<HackathonDetailScreen> createState() => _HackathonDetailScreenState();
}

class _HackathonDetailScreenState extends State<HackathonDetailScreen> {
  final _api = ApiService();
  Competition? _competition;
  bool _loading = true;
  String? _error;
  bool _joining = false;
  bool _joined = false;
  AuthUser? _user;

  // --- Equipe (Team) ---
  Map<String, dynamic>? _myEquipe;
  String? _myRole; // LEADER or MEMBER
  bool _loadingEquipe = false;
  bool _creatingTeam = false;

  // --- Participant status ---
  String _participantStatus = 'JOINED';
  bool _isWinner = false;

  List<CheckpointSubmissionWithCheckpoint> _checkpointSubmissions = [];
  bool _loadingCheckpoints = false;
  @override
  void initState() {
    super.initState();
    _loadUser();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final u = await _api.getMe();
      if (mounted) setState(() => _user = u);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await _api.getCompetitionById(widget.competitionId);

      bool alreadyJoined = false;
      try {
        alreadyJoined = await _api.checkMyParticipation(widget.competitionId);
        if (alreadyJoined) {
          try {
            final details = await _api.getParticipationDetails(widget.competitionId);
            if (details != null) {
              _participantStatus = details['status'] as String? ?? 'JOINED';
              _isWinner = details['isWinner'] as bool? ?? false;
            }
          } catch (_) {}
        }
      } catch (_) {}

      if (mounted) setState(() {
        _competition = c;
        _joined = alreadyJoined;
        _loading = false;
      });

      // Load equipe info
      _loadEquipe();

      if (alreadyJoined) {
        _loadCheckpointSubmissions();
      }
    } on ApiError catch (e) {
      if (e.statusCode == 401 && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
        return;
      }
      if (mounted) setState(() {
        if (e.statusCode == 404) {
          _error = 'HACKATHON_DELETED';
        } else {
          _error = e.displayMessage;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Erreur de connexion';
        _loading = false;
      });
    }
  }

  Future<void> _loadEquipe() async {
    setState(() => _loadingEquipe = true);
    try {
      final equipe = await _api.getMyEquipe(widget.competitionId);
      if (mounted) setState(() {
        _myEquipe = equipe;
        _myRole = equipe?['myRole'] as String?;
        _loadingEquipe = false;
        // If user has equipe, they are "joined"
        if (equipe != null) _joined = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingEquipe = false);
    }
  }

  Future<void> _loadCheckpointSubmissions() async {
    if (!mounted) return;
    setState(() => _loadingCheckpoints = true);
    try {
      final list = await _api.getMyCheckpointSubmissions(widget.competitionId);
      if (mounted) setState(() {
        _checkpointSubmissions = list;
        _loadingCheckpoints = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCheckpoints = false);
    }
  }

  // ─── Create Team ───
  Future<void> _showCreateTeamDialog() async {
    // 1. Prendre une photo obligatoirement avant !
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
    );

    if (image == null) return; // Annulé

    // Copier l'image vers un emplacement permanent pour éviter la suppression de cache
    final dir = await getApplicationDocumentsDirectory();
    final ext = image.name.split('.').last;
    final permanentPath = '${dir.path}/face_image_${widget.competitionId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(image.path).copy(permanentPath);

    // Sauvegarder l'image localement pour l'anti-triche du Checkpoint
    final storage = StorageService();
    await storage.saveData('face_image_${widget.competitionId}', permanentPath);

    // 2. Demander le nom de l'équipe
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2332),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.groups, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Créer une équipe', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Créez votre équipe pour ce hackathon. Vous serez le leader et pourrez inviter des membres.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nom de l\'équipe',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.length >= 2) {
                  Navigator.pop(ctx, name);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    setState(() => _creatingTeam = true);
    try {
      await _api.createEquipe(name: result, competitionId: widget.competitionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Équipe créée avec succès ! Vous êtes le leader.'),
            backgroundColor: Colors.green,
          ),
        );
        _load(); // Reload everything
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _creatingTeam = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _creatingTeam = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la création'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Invite Member ───
  Future<void> _showInviteDialog() async {
    if (_myEquipe == null) return;
    final equipeId = _myEquipe!['id'] as String;
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool searching = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2332),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.person_add, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Inviter un membre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recherchez par nom ou email',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nom ou email...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) async {
                      if (val.trim().length < 2) {
                        setModalState(() => searchResults = []);
                        return;
                      }
                      setModalState(() => searching = true);
                      try {
                        final results = await _api.searchUsersForTeam(
                          val.trim(),
                          competitionId: widget.competitionId,
                        );
                        setModalState(() {
                          searchResults = results;
                          searching = false;
                        });
                      } catch (_) {
                        setModalState(() => searching = false);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.35),
                    child: searchResults.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                searchController.text.trim().length < 2
                                    ? 'Tapez au moins 2 caractères'
                                    : 'Aucun utilisateur trouvé',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: searchResults.length,
                            itemBuilder: (_, i) {
                              final user = searchResults[i];
                              final uName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
                              final uEmail = user['email'] as String? ?? '';
                              final uAvatar = user['avatarUrl'] as String?;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withAlpha(40),
                                  backgroundImage: (uAvatar != null && uAvatar.isNotEmpty)
                                      ? NetworkImage('${ApiService.baseUrl}$uAvatar')
                                      : null,
                                  child: (uAvatar == null || uAvatar.isEmpty)
                                      ? const Icon(Icons.person, color: AppColors.primary, size: 20)
                                      : null,
                                ),
                                title: Text(uName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: Text(uEmail, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                trailing: SizedBox(
                                  height: 34,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await _api.inviteToEquipe(equipeId, uEmail);
                                        if (mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('✅ Invitation envoyée à $uName'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          _loadEquipe();
                                        }
                                      } on ApiError catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
                                          );
                                        }
                                      } catch (_) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Erreur'), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    child: const Text('Inviter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Join via face photo (for direct join without team) ───
  Future<void> _joinWithFacePhoto() async {
    if (_competition == null || !_competition!.canJoin) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
    );

    if (image == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une photo personnelle est obligatoire pour rejoindre ce hackathon (Anti-Triche).'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _joining = true);
    try {
      await _api.joinCompetition(widget.competitionId, File(image.path));
      if (mounted) setState(() {
        _joined = true;
        _joining = false;
      });
      _loadCheckpointSubmissions();
    } on ApiError catch (e) {
      if (mounted) setState(() => _joining = false);
      if (e.statusCode == 409) {
        setState(() => _joined = true);
        return;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (mounted) setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'inscription'), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Open Team Chat ───
  Future<void> _openTeamChat() async {
    if (_myEquipe == null || _user == null) return;

    final equipeId = _myEquipe!['id'] as String;
    final competitionId = widget.competitionId;
    final teamName = _myEquipe!['name'] as String? ?? 'Mon Équipe';

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

      // Get Stream token
      final streamData = await _api.getStreamToken();
      final apiKey = streamData['apiKey'] as String;
      final token = streamData['token'] as String;

      // Join team chat channel
      await _api.joinTeamChat(equipeId, competitionId);

      // Connect to Stream
      final client = stream.StreamChatClient(apiKey);
      await client.connectUser(
        stream.User(id: _user!.id, name: '${_user!.firstName} ${_user!.lastName}'.trim()),
        token,
      );

      // Channel ID matches backend: team-{equipeId}-comp-{competitionId}
      final channelId = 'team-$equipeId-comp-$competitionId';
      final channel = client.channel('messaging', id: channelId);
      await channel.watch();

      if (mounted) Navigator.of(context).pop(); // dismiss loading

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => stream.StreamChat(
              client: client,
              child: stream.StreamChannel(
                channel: channel,
                child: Navigator(
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    builder: (innerContext) => ChatScreen(
                      roomId: channelId,
                      roomName: '💬 $teamName',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'ouverture du chat'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Mark Team Ready ───
  Future<void> _markReady() async {
    if (_myEquipe == null) return;
    try {
      await _api.markTeamReady(_myEquipe!['id'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Équipe marquée comme prête !'), backgroundColor: Colors.green),
        );
        _loadEquipe();
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0B1121), Color(0xFF0F141C), Color(0xFF0B0E14)],
                )
              : null,
          color: isDark ? null : AppColors.backgroundLight,
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _error != null
                  ? _buildErrorView(isDark)
                  : _competition == null
                      ? const SizedBox.shrink()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      icon: Icon(Icons.arrow_back, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Hackathon',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 48),
                                  ],
                                ),
                              ),
                            ),
                            if (_isWinner)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade400,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(color: Colors.amber.withAlpha(50), blurRadius: 10, spreadRadius: 2),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Text('🏆', style: TextStyle(fontSize: 28)),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Félicitations, vous avez gagné !',
                                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Vous avez été sélectionné comme le gagnant de ce hackathon.",
                                          style: TextStyle(fontSize: 14, color: Colors.black.withAlpha(180)),
                                        ),
                                        if (_competition?.creator?.id != null) ...[
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            height: 38,
                                            child: OutlinedButton.icon(
                                              onPressed: () {
                                                Navigator.push(context, MaterialPageRoute(
                                                  builder: (_) => PublicProfileScreen(userId: _competition!.creator!.id),
                                                ));
                                              },
                                              icon: const Icon(Icons.person, size: 16),
                                              label: const Text("Voir le profil de l'organisateur"),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.black87,
                                                side: BorderSide(color: Colors.amber.shade700),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _chip(_competition!.difficultyDisplay, _diffColor()),
                                        if (_competition!.specialty != null) ...[
                                          const SizedBox(width: 8),
                                          _chip(_competition!.specialty!, AppColors.primary),
                                        ],
                                        const Spacer(),
                                        Text(
                                          _competition!.statusDisplay,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _competition!.title,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : AppColors.textLightPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _competition!.description,
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.5,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _infoRow(Icons.calendar_today, '${_formatDate(_competition!.startDate)} – ${_formatDate(_competition!.endDate)}'),
                                    if (_competition!.rewardPool > 0)
                                      _infoRow(Icons.emoji_events, 'Prix : \$${_competition!.rewardPool.toStringAsFixed(0)}'),
                                    if (_competition!.maxParticipants != null)
                                      _infoRow(Icons.people_outline, 'Max ${_competition!.maxParticipants} participants'),
                                    if (_competition!.participantsCount > 0)
                                      _infoRow(Icons.people, '${_competition!.participantsCount} inscrits'),
                                    const SizedBox(height: 24),

                                    // ─── TEAM SECTION (USER role) ───
                                    if (_user?.role == 'USER') ...[
                                      _buildTeamSection(isDark),
                                      if (_joined) ...[
                                        const SizedBox(height: 24),
                                        _buildCheckpointsSection(isDark),
                                      ],
                                    ],

                                    // Admin/Company: view participants button
                                    if (_user?.role == 'ADMIN' || _user?.role == 'COMPANY') ...[
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => AdminParticipantsScreen(
                                                  competitionId: widget.competitionId,
                                                  competitionTitle: _competition!.title,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.people, color: AppColors.primary),
                                          label: const Text(
                                            'Voir les participants',
                                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: AppColors.primary),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                        ),
                                      ),
                                      ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════════
  // TEAM SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTeamSection(bool isDark) {
    // If loading equipe
    if (_loadingEquipe) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      ));
    }

    // If user has NO team
    if (_myEquipe == null) {
      return _buildNoTeamSection(isDark);
    }

    // If user HAS a team
    return _buildTeamDetailsSection(isDark);
  }

  Widget _buildNoTeamSection(bool isDark) {
    final canJoin = _competition?.canJoin ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Mon Équipe',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textLightPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Vous n\'avez pas encore d\'équipe pour ce hackathon. Créez une équipe pour participer et invitez vos coéquipiers !',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          if (canJoin) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pour créer et diriger une équipe, vous devez prendre une photo (Anti-Triche).',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade300),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _creatingTeam ? null : _showCreateTeamDialog,
                icon: _creatingTeam
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.camera_alt, size: 20),
                label: Text(_creatingTeam ? 'Création en cours...' : 'Créer une équipe (Photo requise)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _competition!.statusDisplay,
                  style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamDetailsSection(bool isDark) {
    final teamName = _myEquipe!['name'] as String? ?? 'Mon Équipe';
    final status = _myEquipe!['status'] as String? ?? 'FORMING';
    final members = (_myEquipe!['members'] as List<dynamic>?) ?? [];
    final invitations = ((_myEquipe!['invitations'] as List<dynamic>?) ?? [])
        .where((inv) => inv['status'] == 'PENDING').toList();
    final isLeader = _myRole == 'LEADER';

    Color statusColor;
    String statusText;
    switch (status.toUpperCase()) {
      case 'READY':
        statusColor = Colors.green;
        statusText = 'Prête';
        break;
      case 'DISQUALIFIED':
        statusColor = Colors.red;
        statusText = 'Disqualifiée';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'En formation';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
        boxShadow: isDark ? [BoxShadow(color: AppColors.primary.withAlpha(10), blurRadius: 10)] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF2563EB)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teamName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textLightPrimary)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withAlpha(80)),
                          ),
                          child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                        ),
                        const SizedBox(width: 8),
                        if (isLeader)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.withAlpha(80)),
                            ),
                            child: const Text('👑 Leader', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Membre', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Members list
          Text('Membres (${members.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          ...members.map((m) {
            final user = m['user'] as Map<String, dynamic>? ?? {};
            final role = m['role'] as String? ?? 'MEMBER';
            final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
            final email = user['email'] as String? ?? '';
            final avatar = user['avatarUrl'] as String?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withAlpha(40) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withAlpha(30),
                      backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage('${ApiService.baseUrl}$avatar') : null,
                      child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person, size: 18, color: AppColors.primary) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textLightPrimary)),
                          Text(email, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    if (role == 'LEADER')
                      const Text('👑', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            );
          }),

          // Pending invitations (Hide if group is already full at 6 members)
          if (invitations.isNotEmpty && isLeader && members.length < 6) ...[
            const SizedBox(height: 12),
            Text('Invitations en attente (${invitations.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade400)),
            const SizedBox(height: 6),
            ...invitations.map((inv) {
              final invitee = inv['invitee'] as Map<String, dynamic>? ?? {};
              final iName = '${invitee['firstName'] ?? ''} ${invitee['lastName'] ?? ''}'.trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_bottom, size: 14, color: Colors.orange.shade400),
                    const SizedBox(width: 8),
                    Expanded(child: Text(iName, style: TextStyle(fontSize: 13, color: Colors.orange.shade400))),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Team Chat button
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _openTeamChat,
                    icon: const Icon(Icons.forum, size: 18),
                    label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentCyan,
                      side: const BorderSide(color: AppColors.accentCyan),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              if (isLeader && members.length < 6) ...[
                const SizedBox(width: 8),
                // Invite button
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _showInviteDialog,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Inviter', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Mark Ready button (leader only, FORMING status)
          if (isLeader && status.toUpperCase() == 'FORMING') ...[
            const SizedBox(height: 10),
            if (members.length >= 4)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _markReady,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Marquer l\'équipe prête', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withAlpha(50)),
                ),
                child: const Column(
                  children: [
                    Text('Équipe incomplète', 
                      style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)
                    ),
                    SizedBox(height: 4),
                    Text('Il faut au minimum 4 personnes (leader + 3 membres) pour participer. (Max 6)', 
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: Colors.orange, fontSize: 12)
                    ),
                  ],
                ),
              ),
          ],

          // Info for non-leader
          if (!isLeader) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seul le leader peut inviter des membres et valider les checkpoints pour toute l\'équipe.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CHECKPOINTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCheckpointsSection(bool isDark) {
    final isLeader = _myRole == 'LEADER';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Checkpoints',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textLightPrimary,
                  ),
                ),
              ),
              if (!_loadingCheckpoints)
                IconButton(
                  onPressed: _loadCheckpointSubmissions,
                  icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Rafraîchir',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isLeader
                ? 'En tant que leader, vous validez les checkpoints pour toute l\'équipe.'
                : 'Votre leader valide les checkpoints pour toute l\'équipe automatiquement.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          if (_loadingCheckpoints) ...[
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            ),
          ] else if (_checkpointSubmissions.isEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _myEquipe == null 
                    ? 'Formez une équipe pour voir vos checkpoints'
                    : 'En attente de l\'initialisation des checkpoints équipe',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ..._checkpointSubmissions.map((sub) => _buildCheckpointSubmissionTile(isDark, sub, isLeader)),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckpointSubmissionTile(bool isDark, CheckpointSubmissionWithCheckpoint sub, bool isLeader) {
    // Heuristic: If it's missed but we are a member, it might be a sync issue.
    // We treat APPROVED and SUBMITTED as orange/green.
    final statusColor = sub.isApproved
        ? Colors.green
        : sub.isRejected
            ? Colors.red
            : sub.isSubmitted
                ? Colors.orange
                : sub.isMissed 
                   ? (isLeader ? Colors.red : Colors.grey.shade600) // Gray for members if missed (less scary)
                   : AppColors.primary;

    final displayStatus = (sub.isMissed && !isLeader) 
        ? "En attente du leader" 
        : sub.statusDisplay;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sub.checkpoint.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textLightPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Échéance ${_formatDate(sub.checkpoint.dueDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.lock_open, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Ouvre ${_formatDateTime(sub.checkpoint.opensAt)} · Ferme ${_formatDateTime(sub.checkpoint.dueDate)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
            if (isLeader && (sub.isSubmitted || sub.isApproved) && sub.proofUrl != null && sub.proofUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      sub.proofUrl!,
                      style: const TextStyle(fontSize: 12, color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (!sub.isSubmitted && !sub.isApproved) ...[
              if (sub.proofUrl != null && sub.proofUrl!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.link, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        sub.proofUrl!,
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              // Only leader can submit checkpoints
              if (sub.canSubmit && isLeader) ...[
                if (_myEquipe != null && _myEquipe!['status'] == 'READY') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CountdownText(
                            targetDate: sub.checkpoint.dueDate,
                            prefix: 'Temps restant : ',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => SubmitCheckpointScreen(
                              competitionId: widget.competitionId,
                              checkpointId: sub.checkpointId,
                              checkpointTitle: sub.checkpoint.title,
                              dueDate: sub.checkpoint.dueDate,
                              opensAt: sub.checkpoint.opensAt,
                              initialSubmission: sub,
                              isLeader: isLeader,
                              onSubmitted: _loadCheckpointSubmissions,
                            ),
                          ),
                        );
                        if (result == true && mounted) _loadCheckpointSubmissions();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Soumettre pour l\'équipe', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Action requise : Formez une équipe complète (4 à 6 personnes) et marquez-la comme "Prête" dans l\'onglet Équipe pour débloquer la validation.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else if (sub.canSubmit && !isLeader) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Seul le leader peut valider ce checkpoint.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (sub.notYetOpen) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CountdownText(
                          targetDate: sub.checkpoint.opensAt,
                          prefix: 'S\'ouvre dans : ',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (sub.windowClosed) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Fenêtre de soumission fermée',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  Color _diffColor() {
    if (_competition == null) return AppColors.primary;
    return _competition!.difficulty.toUpperCase() == 'HARD'
        ? AppColors.accentOrange
        : _competition!.difficulty.toUpperCase() == 'EASY'
            ? Colors.green
            : AppColors.primary;
  }

  Widget _buildErrorView(bool isDark) {
    final bool isDeleted = _error == 'HACKATHON_DELETED';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDeleted ? Colors.orange.withAlpha(20) : Colors.red.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDeleted ? Icons.history_toggle_off_rounded : Icons.error_outline_rounded,
                size: 80,
                color: isDeleted ? Colors.orangeAccent : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              isDeleted ? 'Hackathon Indisponible' : 'Une erreur est survenue',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textLightPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isDeleted
                  ? "Ce hackathon a été archivé ou supprimé par l'organisateur. Ses détails ne sont plus accessibles."
                  : _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushNamedAndRemoveUntil('/shell', (route) => false);
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text(
                  'Retour à l\'accueil',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDeleted ? Colors.orangeAccent : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            if (!isDeleted) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade300, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatDateTime(DateTime d) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day} à $h:$m';
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

/// Self-contained countdown widget — only rebuilds itself every second,
/// instead of rebuilding the entire HackathonDetailScreen (1500+ lines).
class _CountdownText extends StatefulWidget {
  final DateTime targetDate;
  final String prefix;
  final TextStyle style;

  const _CountdownText({
    required this.targetDate,
    required this.prefix,
    required this.style,
  });

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.prefix}${_formatDuration(widget.targetDate.difference(DateTime.now()))}',
      style: widget.style,
    );
  }
}
