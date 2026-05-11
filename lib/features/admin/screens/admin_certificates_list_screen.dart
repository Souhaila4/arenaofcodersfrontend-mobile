import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Liste des certificats NFT émis (réservé admin).
class AdminCertificatesListScreen extends StatefulWidget {
  const AdminCertificatesListScreen({super.key});

  @override
  State<AdminCertificatesListScreen> createState() =>
      _AdminCertificatesListScreenState();
}

class _AdminCertificatesListScreenState extends State<AdminCertificatesListScreen> {
  final _api = ApiService();
  final List<dynamic> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _total = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _items.clear();
      });
    } else {
      if (_loadingMore || _items.length >= _total) return;
      setState(() => _loadingMore = true);
    }

    try {
      final offset = reset ? 0 : _items.length;
      final data = await _api.getAdminCertificates(limit: _pageSize, offset: offset);
      if (!mounted) return;
      final raw = data['items'];
      final list = raw is List<dynamic> ? raw : <dynamic>[];
      final total = (data['total'] as num?)?.toInt() ?? 0;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(list);
        } else {
          _items.addAll(list);
        }
        _total = total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiError ? e.displayMessage : e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final u = Uri.parse(url);
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  Widget _buildRow(Map<String, dynamic> row) {
    final user = row['user'] as Map<String, dynamic>?;
    final name = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : 'Utilisateur inconnu';
    final email = user?['email'] as String? ?? '';
    final hack = row['hackathonName'] as String? ?? '';
    final preview = row['imagePreviewUrl'] as String? ?? '';
    final hashscan = row['hashscanNftUrl'] as String? ?? '';
    final transferred = row['transferredToWallet'] == true;
    final minted = _fmtDate(row['mintedAt'] as String?);

    return Card(
      color: const Color(0xFF1A2332),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openUrl(hashscan),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: preview.isNotEmpty
                      ? Image.network(
                          preview,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const ColoredBox(
                            color: Color(0xFF0F172A),
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white38,
                            ),
                          ),
                        )
                      : const ColoredBox(
                          color: Color(0xFF0F172A),
                          child: Icon(
                            Icons.workspace_premium,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hack,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          label: Text(
                            transferred ? 'Transféré wallet' : 'Non transféré',
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: transferred
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: transferred
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                          ),
                        ),
                        Text(
                          minted,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: () => _openUrl(hashscan),
                        icon: const Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: Color(0xFF0D6CF2),
                        ),
                        label: const Text(
                          'HashScan',
                          style: TextStyle(color: Color(0xFF0D6CF2)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (_items.isEmpty) return const SizedBox.shrink();
    if (_items.length >= _total) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _total == 0 ? 'Aucun certificat enregistré' : 'Fin de la liste ($_total)',
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _loadingMore
            ? const CircularProgressIndicator(color: Color(0xFF0D6CF2))
            : TextButton(
                onPressed: () => _load(reset: false),
                child: const Text('Charger plus'),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Certificats NFT',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loading ? null : () => _load(reset: true),
          ),
        ],
      ),
      body: _loading && _items.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D6CF2)),
            )
          : _error != null && _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade300),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _load(reset: true),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF0D6CF2),
                  onRefresh: () => _load(reset: true),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length + 1,
                    itemBuilder: (context, index) {
                      if (index < _items.length) {
                        return _buildRow(_items[index] as Map<String, dynamic>);
                      }
                      return _buildFooter();
                    },
                  ),
                ),
    );
  }
}
