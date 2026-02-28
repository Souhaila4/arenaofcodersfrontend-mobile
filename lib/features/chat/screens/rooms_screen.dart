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
    } on ApiError catch (e) {
      if (e.statusCode == 401 && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
        return;
      }
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load rooms');
    } finally {
      if (mounted) setState(() => _loading = false);
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
                child: ChatScreen(
                  roomId: room['id'],
                  roomName: room['name'],
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
                child: const ChatScreen(
                  roomId: 'arena-live',
                  roomName: 'Arena Live',
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
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
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
