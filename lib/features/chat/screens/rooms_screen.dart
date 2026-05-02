import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/features/chat/screens/chat_screen.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream;

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _rooms = [];
  AuthUser? _user;

  // Team chats : liste de { equipeId, competitionId, teamName, competitionTitle, memberCount, status }
  List<Map<String, dynamic>> _teamChats = [];
  bool _loadingTeamChats = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final u = await _api.getMe();
      if (mounted) setState(() => _user = u);

      final rooms = await _api.getStreamRooms();
      if (mounted) setState(() => _rooms = rooms);

      // Charger les team chats en parallèle
      _loadTeamChats();
    } on ApiError catch (e) {
      if (e.statusCode == 401 && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
        return;
      }
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Erreur de chargement');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Charge les team chats pour les compétitions actives de l'utilisateur
  Future<void> _loadTeamChats() async {
    if (_user == null) return;
    setState(() => _loadingTeamChats = true);

    try {
      // Récupérer les compétitions auxquelles l'utilisateur participe
      final compResponse = await _api.getCompetitionsForMe(limit: 50);
      final List<Map<String, dynamic>> chats = [];

      for (final comp in compResponse.data) {
        // Vérifier si l'utilisateur a une équipe dans cette compétition
        try {
          final equipe = await _api.getMyEquipe(comp.id);
          if (equipe != null) {
            final members = (equipe['members'] as List<dynamic>?) ?? [];
            final teamName = equipe['name'] as String? ?? 'Équipe';
            final status = equipe['status'] as String? ?? 'FORMING';
            chats.add({
              'equipeId': equipe['id'],
              'competitionId': comp.id,
              'teamName': teamName,
              'competitionTitle': comp.title,
              'memberCount': members.length,
              'status': status,
            });
          }
        } catch (_) {
          // Pas d'équipe pour cette compétition, on continue
        }
      }

      if (mounted) {
        setState(() {
          _teamChats = chats;
          _loadingTeamChats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTeamChats = false);
    }
  }

  /// Ouvrir le chat privé d'une équipe
  Future<void> _openTeamChat(Map<String, dynamic> teamChat) async {
    if (_user == null) return;

    final equipeId = teamChat['equipeId'] as String;
    final competitionId = teamChat['competitionId'] as String;
    final teamName = teamChat['teamName'] as String;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

      final streamData = await _api.getStreamToken();
      final apiKey = streamData['apiKey'] as String;
      final token = streamData['token'] as String;

      // Rejoindre le canal chat de l'équipe
      await _api.joinTeamChat(equipeId, competitionId);

      final client = stream.StreamChatClient(apiKey);
      await client.connectUser(
        stream.User(id: _user!.id, name: '${_user!.firstName} ${_user!.lastName}'.trim()),
        token,
      );

      // Channel ID = team-{equipeId}-comp-{competitionId} (identique au backend)
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

  Future<void> _joinRoom(Map<String, dynamic> room) async {
    final bool canJoin = room['canParticipate'] == true;
    if (!canJoin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot join ${room['name']}. Your specialty is ${_user?.mainSpecialty ?? "Not Set"}.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
      final streamData = await _api.getStreamToken();
      final apiKey = streamData['apiKey'] as String;
      final token = streamData['token'] as String;

      await _api.joinStreamRoom(room['id']);
      
      final client = stream.StreamChatClient(apiKey);
      await client.connectUser(
        stream.User(id: _user!.id, name: '${_user!.firstName} ${_user!.lastName}'.trim()),
        token,
      );

      final channel = client.channel('messaging', id: room['id']);
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
                      roomId: room['id'],
                      roomName: room['name'],
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error joining room'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _joinArenaLive() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
      final streamData = await _api.getStreamToken();
      final apiKey = streamData['apiKey'] as String;
      final token = streamData['token'] as String;

      await _api.joinArenaLive();

      final client = stream.StreamChatClient(apiKey);
      await client.connectUser(
        stream.User(id: _user!.id, name: '${_user!.firstName} ${_user!.lastName}'.trim()),
        token,
      );

      final channel = client.channel('messaging', id: 'arena-live');
      await channel.watch();

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => stream.StreamChat(
              client: client,
              child: stream.StreamChannel(
                channel: channel,
                child: Navigator(
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    builder: (innerContext) => const ChatScreen(
                      roomId: 'arena-live',
                      roomName: 'Arena Live',
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error joining Arena Live'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141C) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Comms Rooms', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      TextButton(onPressed: _load, child: const Text('Réessayer')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: CustomScrollView(
                    slivers: [
                      // ────── TEAM CHATS SECTION ──────
                      if (_teamChats.isNotEmpty || _loadingTeamChats) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF2563EB)]),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Icon(Icons.groups, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'MES CHATS D\'ÉQUIPE',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey.shade500),
                                ),
                                if (_loadingTeamChats) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (_teamChats.isNotEmpty)
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final tc = _teamChats[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                  child: _buildTeamChatCard(context, tc, isDark),
                                );
                              },
                              childCount: _teamChats.length,
                            ),
                          ),
                        if (_loadingTeamChats && _teamChats.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: Text('Chargement...', style: TextStyle(color: Colors.grey))),
                            ),
                          ),
                      ],

                      // ────── GLOBAL CHANNEL ──────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GLOBAL CHANNEL',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 16),
                              _buildRoomCard(
                                context,
                                title: 'Arena Live',
                                description: 'General chat for all participants & real-time announcements.',
                                icon: Icons.public,
                                iconColor: AppColors.accentCyan,
                                canJoin: true,
                                onTap: _joinArenaLive,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ────── SPECIALTY ROOMS ──────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text(
                            'SPECIALTY ROOMS',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final room = _rooms[index] as Map<String, dynamic>;
                            final canJoin = room['canParticipate'] == true;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: _buildRoomCard(
                                context,
                                title: room['name'] ?? 'Room',
                                description: room['description'] ?? '',
                                icon: Icons.code,
                                iconColor: canJoin ? AppColors.primary : Colors.grey,
                                canJoin: canJoin,
                                onTap: () => _joinRoom(room),
                                isDark: isDark,
                              ),
                            );
                          },
                          childCount: _rooms.length,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
    );
  }

  // ────── Team Chat Card ──────
  Widget _buildTeamChatCard(BuildContext context, Map<String, dynamic> tc, bool isDark) {
    final teamName = tc['teamName'] as String;
    final compTitle = tc['competitionTitle'] as String;
    final memberCount = tc['memberCount'] as int;
    final status = tc['status'] as String;

    Color statusColor;
    String statusText;
    switch (status.toUpperCase()) {
      case 'READY':
        statusColor = Colors.green;
        statusText = 'Prête';
        break;
      case 'DISQUALIFIED':
        statusColor = Colors.red;
        statusText = 'DQ';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'En formation';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openTeamChat(tc),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2332) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withAlpha(80), width: 1.5),
            boxShadow: isDark
                ? [BoxShadow(color: AppColors.primary.withAlpha(15), blurRadius: 10, spreadRadius: 2)]
                : [BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 6)],
          ),
          child: Row(
            children: [
              // Team icon avec gradient
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.forum, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom de l'équipe
                    Text(
                      teamName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Nom du hackathon
                    Text(
                      compTitle,
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Membres + statut
                    Row(
                      children: [
                        Icon(Icons.people, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '$memberCount membres',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor.withAlpha(60)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required bool canJoin,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2332) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canJoin ? iconColor.withAlpha(80) : Colors.grey.withAlpha(50),
              width: 1.5,
            ),
            boxShadow: [
              if (canJoin && isDark)
                BoxShadow(
                  color: iconColor.withAlpha(20),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (canJoin)
                Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400)
              else
                Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
