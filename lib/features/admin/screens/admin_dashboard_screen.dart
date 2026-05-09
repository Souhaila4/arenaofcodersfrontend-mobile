import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/models/arena_mirror_model.dart';
import 'package:arena/features/courses/screens/admin_courses_screen.dart';
import 'package:arena/features/admin/screens/admin_arena_mint_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _api = ApiService();
  final _storage = StorageService();

  // Company Requests State
  bool _isLoadingRequests = true;
  List<dynamic> _requests = [];

  // Users State
  bool _isLoadingUsers = true;
  List<dynamic> _users = [];
  String _selectedRole = 'ALL';
  final _searchController = TextEditingController();

  // Mirror On-chain Logs (admin)
  bool _isLoadingMirror = true;
  bool _isLoadingMoreMirror = false;
  String? _mirrorError;
  bool _cryptotransferOnly = false;
  String? _nextMirror;
  String _mirrorTokenId = '';
  List<ArenaMirrorTransactionItem> _mirrorTxs = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _loadUsers();
    _loadMirrorTransactions(reset: true);
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final data = await _api.getCompanyRequests(status: 'PENDING');
      if (mounted) {
        setState(() {
          _requests = data;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
    }
  }

  Future<void> _reviewRequest(String id, String status) async {
    try {
      await _api.reviewCompanyRequest(id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Demande $status avec succès', style: const TextStyle(color: Colors.white))));
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e', style: const TextStyle(color: Colors.white))));
      }
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final offset = 0;
      final limit = 50;
      final search = _searchController.text.trim();
      
      final token = await _storage.getToken();
      if (token == null) throw Exception("Not authenticated");

      final uri = Uri.parse('${ApiService.baseUrl}/admin/users').replace(
        queryParameters: {
          'limit': limit.toString(),
          'offset': offset.toString(),
          if (search.isNotEmpty) 'search': search,
          if (_selectedRole != 'ALL') 'role': _selectedRole,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _users = data['users'] ?? [];
            _isLoadingUsers = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingUsers = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _loadMirrorTransactions({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoadingMirror = true;
        _mirrorError = null;
        _nextMirror = null;
        _mirrorTxs = [];
      });
    } else {
      if (_nextMirror == null || _isLoadingMoreMirror) return;
      setState(() => _isLoadingMoreMirror = true);
    }

    try {
      if (reset) {
        const maxEmptySkips = 12;
        String? cursor;
        final merged = <ArenaMirrorTransactionItem>[];
        ArenaMirrorTransactionsPage? firstPage;

        for (var i = 0; i < maxEmptySkips; i++) {
          final page = await _api.getAdminMirrorArenaTransactions(
            limit: 25,
            next: cursor,
            cryptotransferOnly: _cryptotransferOnly,
          );
          firstPage ??= page;
          merged.addAll(page.transactions);
          cursor = page.next;
          if (merged.isNotEmpty || cursor == null) {
            if (!mounted) return;
            setState(() {
              _mirrorTokenId = firstPage!.tokenId;
              _mirrorTxs = merged;
              _nextMirror = cursor;
            });
            return;
          }
        }
        if (!mounted) return;
        setState(() {
          _mirrorTokenId = firstPage?.tokenId ?? '';
          _mirrorTxs = merged;
          _nextMirror = cursor;
        });
      } else {
        final page = await _api.getAdminMirrorArenaTransactions(
          limit: 25,
          next: _nextMirror,
          cryptotransferOnly: _cryptotransferOnly,
        );
        if (!mounted) return;
        setState(() {
          _mirrorTxs.addAll(page.transactions);
          _nextMirror = page.next;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mirrorError = _readableMirrorError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMirror = false;
          _isLoadingMoreMirror = false;
        });
      }
    }
  }

  String _readableMirrorError(Object e) {
    if (e is ApiError) {
      if (e.statusCode == 429) {
        return 'Rate limit Hedera atteint (429). Réessayez dans quelques secondes.';
      }
      return e.displayMessage;
    }
    return e.toString();
  }

  String _fmtMirrorDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final d = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E293B),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Demandes Entreprise"),
              Tab(text: "Liste Utilisateurs"),
              Tab(text: "Gestion Cours"),
              Tab(text: "Arena — Traçabilité"),
              Tab(text: "Logs On-chain"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequestsTab(),
            _buildUsersTab(),
            const AdminCoursesScreen(),
            const AdminArenaMintTab(),
            _buildMirrorTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoadingRequests) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_requests.isEmpty) return const Center(child: Text('Aucune demande en attente', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final req = _requests[index];
        final user = req['user'] ?? {};
        return Card(
          color: const Color(0xFF1A2332),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text('${req['companyName']} (${user['firstName']} ${user['lastName']})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(req['description'] ?? 'Pas de description', style: const TextStyle(color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  tooltip: 'Accepter',
                  onPressed: () => _reviewRequest(req['id'], 'APPROVED'),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Refuser',
                  onPressed: () => _reviewRequest(req['id'], 'REJECTED'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un email ou un nom...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _loadUsers(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Tous')),
                      DropdownMenuItem(value: 'USER', child: Text('User')),
                      DropdownMenuItem(value: 'COMPANY', child: Text('Entreprise')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRole = val);
                        _loadUsers();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _users.isEmpty
                  ? const Center(child: Text('Aucun utilisateur trouvé', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final u = _users[index];
                        final firstName = u['firstName'] ?? '';
                        final lastName = u['lastName'] ?? '';
                        final initial = firstName.isNotEmpty ? firstName[0] : (lastName.isNotEmpty ? lastName[0] : '?');

                        return Card(
                          color: const Color(0xFF1A2332),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                              child: Text(
                                initial,
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text('$firstName $lastName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(u['email'] ?? '', style: const TextStyle(color: Colors.grey)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: u['role'] == 'ADMIN'
                                    ? Colors.purple.withValues(alpha: 0.2)
                                    : u['role'] == 'COMPANY'
                                        ? Colors.orange.withValues(alpha: 0.2)
                                        : Colors.cyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                u['role'] ?? 'USER',
                                style: TextStyle(
                                  color: u['role'] == 'ADMIN' ? Colors.purpleAccent : u['role'] == 'COMPANY' ? Colors.orangeAccent : Colors.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildMirrorTab() {
    if (_isLoadingMirror) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_mirrorError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 34),
              const SizedBox(height: 12),
              Text(
                _mirrorError!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _loadMirrorTransactions(reset: true),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_mirrorTxs.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadMirrorTransactions(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMirrorHeader(),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Aucune ligne Arena Coin trouvée pour le trésor sur les pages parcourues.\n'
                'Désactivez « CRYPTOTRANSFER only » ou appuyez sur « Charger plus » si d’autres pages existent.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            if (_nextMirror != null) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _isLoadingMoreMirror
                      ? null
                      : () => _loadMirrorTransactions(reset: false),
                  child: const Text('Charger plus (pages suivantes)'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMirrorTransactions(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mirrorTxs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildMirrorHeader();
          }

          final tx = _mirrorTxs[index - 1];
          return Card(
            color: const Color(0xFF1A2332),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.transactionId ?? 'ID indisponible',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_fmtMirrorDate(tx.consensusAtIso)} • ${tx.type ?? 'UNKNOWN'} • ${tx.result ?? 'N/A'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  if (tx.transfers.isNotEmpty)
                    ...tx.transfers.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${t.sender} → ${t.receiver}\nMontant: ${t.amount.toStringAsFixed(2)} ARENA (raw: ${t.amountRaw})',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  if (tx.transfers.isEmpty && tx.rawTokenLegs.isNotEmpty)
                    ...tx.rawTokenLegs.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Compte: ${r.account}\nMontant: ${r.amount.toStringAsFixed(2)} ARENA (raw: ${r.amountRaw})',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMirrorHeader() {
    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Token: ${_mirrorTokenId.isEmpty ? 'N/A' : _mirrorTokenId}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _cryptotransferOnly,
                    title: const Text(
                      'CRYPTOTRANSFER only',
                      style: TextStyle(color: Colors.white),
                    ),
                    onChanged: (v) {
                      setState(() => _cryptotransferOnly = v);
                      _loadMirrorTransactions(reset: true);
                    },
                  ),
                ),
                TextButton(
                  onPressed: _isLoadingMoreMirror || _nextMirror == null
                      ? null
                      : () => _loadMirrorTransactions(reset: false),
                  child: _isLoadingMoreMirror
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Charger plus'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
