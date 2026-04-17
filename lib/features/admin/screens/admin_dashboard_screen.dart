import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/services/storage_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _loadUsers();
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E293B),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Demandes Entreprise"),
              Tab(text: "Liste Utilisateurs"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequestsTab(),
            _buildUsersTab(),
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
                              backgroundColor: AppColors.primary.withOpacity(0.2),
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
                                color: u['role'] == 'ADMIN' ? Colors.purple.withOpacity(0.2) : u['role'] == 'COMPANY' ? Colors.orange.withOpacity(0.2) : Colors.cyan.withOpacity(0.2),
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
}
