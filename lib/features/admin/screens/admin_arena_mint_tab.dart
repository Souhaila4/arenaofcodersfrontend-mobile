import 'dart:io';

import 'package:arena/core/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const _pm = <String, String>{
  'BANK_TRANSFER': 'Virement bancaire',
  'WIRE_SWIFT': 'SWIFT / international',
  'CARD': 'Carte bancaire',
  'WISE': 'Wise',
  'PAYPAL': 'PayPal',
  'CRYPTO_STABLECOIN': 'Crypto (stablecoin)',
  'CASH': 'Espèces / autre',
  'OTHER': 'Autre',
};

class AdminArenaMintTab extends StatefulWidget {
  const AdminArenaMintTab({super.key});

  @override
  State<AdminArenaMintTab> createState() => _AdminArenaMintTabState();
}

class _AdminArenaMintTabState extends State<AdminArenaMintTab> {
  final _api = ApiService();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _fiatAmountCtrl = TextEditingController();
  final _fiatCurCtrl = TextEditingController(text: 'EUR');
  final _notesCtrl = TextEditingController();
  final _proofUrlCtrl = TextEditingController();

  List<dynamic> _companies = [];
  String? _companyId;
  String _paymentMethod = 'BANK_TRANSFER';
  DateTime? _paymentDate;
  List<int>? _proofBytes;
  String? _proofName;

  bool _loadingCompanies = true;
  bool _submitting = false;

  List<dynamic> _auditRows = [];
  bool _loadingAudit = true;
  int _auditPage = 1;
  int _auditTotalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _loadAudit();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _fiatAmountCtrl.dispose();
    _fiatCurCtrl.dispose();
    _notesCtrl.dispose();
    _proofUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() => _loadingCompanies = true);
    try {
      final users = await _api.getAdminUsersList(role: 'COMPANY', limit: 500);
      if (mounted) {
        setState(() {
          _companies = users;
          _loadingCompanies = false;
          if (_companyId == null && _companies.isNotEmpty) {
            _companyId = (_companies.first as Map)['id'] as String?;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCompanies = false);
    }
  }

  Future<void> _loadAudit() async {
    setState(() => _loadingAudit = true);
    try {
      final data = await _api.getWalletAdminFundings(page: _auditPage, limit: 15);
      if (mounted) {
        setState(() {
          _auditRows = data['items'] as List<dynamic>? ?? [];
          final total = (data['total'] as num?)?.toInt() ?? 0;
          final limit = (data['limit'] as num?)?.toInt() ?? 15;
          _auditTotalPages = (total / limit).ceil().clamp(1, 9999);
          _loadingAudit = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAudit = false);
    }
  }

  Future<void> _pickProof() async {
    final r = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'doc', 'docx'],
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    setState(() {
      _proofBytes = f.bytes?.toList();
      _proofName = f.name;
    });
  }

  Future<void> _submit() async {
    final cid = _companyId;
    if (cid == null || cid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une entreprise')),
      );
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant Arena Coin invalide')),
      );
      return;
    }
    if (_refCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Référence de paiement obligatoire')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final fiat = double.tryParse(_fiatAmountCtrl.text.replaceAll(',', '.'));
      await _api.adminMintWithTraceMultipart(
        userId: cid,
        amount: amount,
        paymentMethod: _paymentMethod,
        paymentReference: _refCtrl.text.trim(),
        fiatAmount: fiat != null && fiat >= 0 ? fiat : null,
        fiatCurrency: _fiatCurCtrl.text.trim().length == 3
            ? _fiatCurCtrl.text.trim().toUpperCase()
            : null,
        paymentDate: _paymentDate?.toUtc().toIso8601String(),
        internalNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        proofDocumentUrl: _proofUrlCtrl.text.trim().isEmpty ? null : _proofUrlCtrl.text.trim(),
        proofBytes: _proofBytes,
        proofFilename: _proofName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Crédit Arena enregistré (mint + traçabilité)'),
            backgroundColor: Color(0xFF1A3A2A),
          ),
        );
        _amountCtrl.clear();
        _refCtrl.clear();
        _notesCtrl.clear();
        setState(() {
          _proofBytes = null;
          _proofName = null;
          _paymentDate = null;
        });
        await _loadAudit();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade900),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openHashscan(String? txId) async {
    if (txId == null || txId.isEmpty) return;
    final uri = Uri.parse(
      'https://hashscan.io/testnet/transaction/$txId',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _downloadProof(String fundingId, String? filename) async {
    try {
      final bytes = await _api.downloadAdminFundingProof(fundingId);
      final dir = await getTemporaryDirectory();
      final name = (filename != null && filename.isNotEmpty)
          ? filename
          : 'preuve_${fundingId.substring(0, 8)}.bin';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Téléchargement impossible: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Crédit entreprise + traçabilité',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Le fichier justificatif est chiffré sur le serveur ; une empreinte '
            '(SHA-256) peut être ancrée sur Hedera (topic HCS) si configuré.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (_loadingCompanies)
            const Center(child: CircularProgressIndicator(color: Color(0xFF0D6CF2)))
          else
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF1E293B),
              value: _companyId,
              decoration: _dec('Entreprise (COMPANY)'),
              items: _companies.map((u) {
                final m = u as Map<String, dynamic>;
                final id = m['id'] as String? ?? '';
                final fn = m['firstName'] ?? '';
                final ln = m['lastName'] ?? '';
                final em = m['email'] ?? '';
                return DropdownMenuItem(
                  value: id,
                  child: Text(
                    '$fn $ln — $em',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _companyId = v),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: _dec('Montant Arena Coins'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            dropdownColor: const Color(0xFF1E293B),
            value: _paymentMethod,
            decoration: _dec('Mode de paiement (réel)'),
            items: _pm.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: const TextStyle(color: Colors.white)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _paymentMethod = v ?? 'BANK_TRANSFER'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _refCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('Référence virement / transaction'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fiatAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Montant fiat (optionnel)'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: _fiatCurCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Devise'),
                  maxLength: 3,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: const Color(0xFF1A2332),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              _paymentDate == null
                  ? 'Date du paiement (optionnel)'
                  : _paymentDate!.toLocal().toString().split(' ').first,
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.calendar_today, color: Color(0xFF0D6CF2)),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _paymentDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (d != null) setState(() => _paymentDate = d);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('Notes internes (optionnel)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _proofUrlCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('URL preuve externe (optionnel, si pas de fichier)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickProof,
            icon: const Icon(Icons.attach_file, color: Color(0xFF00C2FF)),
            label: Text(
              _proofName ?? 'Joindre un justificatif (PDF, image…)',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D6CF2),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Valider crédit + mint'),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Journal d’audit',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              TextButton(
                onPressed: _loadingAudit ? null : _loadAudit,
                child: const Text('Rafraîchir'),
              ),
            ],
          ),
          if (_loadingAudit)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF0D6CF2))),
            )
          else if (_auditRows.isEmpty)
            Text('Aucune entrée', style: TextStyle(color: Colors.grey.shade500))
          else
            ..._auditRows.map((row) {
              final m = row as Map<String, dynamic>;
              final id = m['id'] as String? ?? '';
              final benef = m['beneficiary'] as Map<String, dynamic>?;
              final name = benef != null
                  ? '${benef['firstName'] ?? ''} ${benef['lastName'] ?? ''}'
                  : '';
              final anchor = m['proofHederaAnchorTxId'] as String?;
              final sha = m['proofSha256Hex'] as String?;
              final hasFile = (m['proofEncryptedPath'] as String?)?.isNotEmpty == true;
              final fname = m['proofOriginalFilename'] as String?;
              return Card(
                color: const Color(0xFF1A2332),
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name · ${m['arenaCoinAmount'] ?? '?'} ARENA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Réf: ${m['paymentReference'] ?? ''} · ${m['paymentMethod'] ?? ''}',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                      if (sha != null && sha.isNotEmpty)
                        Text(
                          'SHA-256 (chiffré): ${sha.substring(0, 16)}…',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (anchor != null && anchor.isNotEmpty)
                            TextButton(
                              onPressed: () => _openHashscan(anchor),
                              child: const Text('Voir ancre Hedera'),
                            ),
                          if (hasFile)
                            TextButton(
                              onPressed: () => _downloadProof(id, fname),
                              child: const Text('Télécharger preuve'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _auditPage > 1 && !_loadingAudit
                    ? () {
                        _auditPage--;
                        _loadAudit();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Text(
                'Page $_auditPage / $_auditTotalPages',
                style: const TextStyle(color: Colors.white54),
              ),
              IconButton(
                onPressed: _auditPage < _auditTotalPages && !_loadingAudit
                    ? () {
                        _auditPage++;
                        _loadAudit();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0D6CF2)),
        ),
        filled: true,
        fillColor: const Color(0xFF0F172A),
      );
}
