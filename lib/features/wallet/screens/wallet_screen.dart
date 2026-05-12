import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:arena/core/models/auth_models.dart' show ApiError;
import 'package:arena/core/models/wallet_model.dart';
import 'package:arena/core/services/api_service.dart';

const _blue = Color(0xFF0D6CF2);
const _cyan = Color(0xFF00C2FF);
const _cardBg = Color(0xFF1A2332);
const _darkBg = Color(0xFF0F141C);

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  WalletInfo? _wallet;
  bool _loading = true;
  String? _error;
  String? _userRole;
  List<dynamic> _fiatTraceRows = const [];
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final _adminMintHederaController = TextEditingController();
  final _adminMintAmountController = TextEditingController();
  bool _adminMintBusy = false;

  bool get _isAdmin => _userRole == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadWallet();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _adminMintHederaController.dispose();
    _adminMintAmountController.dispose();
    super.dispose();
  }

  String _mintErrorMessage(Object e) {
    if (e is ApiError) return e.displayMessage;
    return e.toString();
  }

  Future<void> _runAdminMintFlow() async {
    final hed = _adminMintHederaController.text.trim();
    final amount = double.tryParse(
      _adminMintAmountController.text.trim().replaceAll(',', '.'),
    );
    if (hed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrez l’ID de compte Hedera du destinataire (ex. 0.0.123456).'),
          backgroundColor: Color(0xFF5C1A1A),
        ),
      );
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrez un montant valide supérieur à 0.'),
          backgroundColor: Color(0xFF5C1A1A),
        ),
      );
      return;
    }

    setState(() => _adminMintBusy = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: _cardBg,
        content: Row(
          children: [
            CircularProgressIndicator(color: _cyan),
            SizedBox(width: 20),
            Expanded(child: Text('Recherche du destinataire…', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );

    try {
      final preview = await _api.adminResolveRecipientByHedera(hed);
      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;
      final first = preview['firstName']?.toString() ?? '';
      final last = preview['lastName']?.toString() ?? '';
      final displayName = '$first $last'.trim().isEmpty ? 'Utilisateur inconnu' : '$first $last'.trim();

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _AdminMintCountdownDialog(
          displayName: displayName,
          hederaAccountId: hed,
          amount: amount,
        ),
      );

      if (confirmed != true || !mounted) {
        return;
      }

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          backgroundColor: _cardBg,
          content: Row(
            children: [
              CircularProgressIndicator(color: _cyan),
              SizedBox(width: 20),
              Expanded(child: Text('Envoi des ARENA…', style: TextStyle(color: Colors.white))),
            ],
          ),
        ),
      );

      try {
        final res = await _api.adminMintArenaCoins(
          recipientHederaAccountId: hed,
          amount: amount,
        );
        if (mounted) Navigator.of(context).pop();

        if (!mounted) return;
        final ok = res['success'] == true;
        final note = res['note']?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Envoyé ${res['amount']} ARENA (solde app: ${res['newBalance']}).'
                  : 'Échec partiel: ${note ?? res.toString()}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: ok ? const Color(0xFF1A3A2A) : Colors.orange.shade900,
          ),
        );
        if (ok) _adminMintAmountController.clear();
        await _loadWallet();
      } catch (mintErr) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_mintErrorMessage(mintErr)),
              backgroundColor: Colors.red.shade900,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mintErrorMessage(e)),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adminMintBusy = false);
    }
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final w = await _api.getMyWallet();
      final me = await _api.getMe();
      var trace = <dynamic>[];
      if (me.role == 'COMPANY') {
        try {
          trace = await _api.getMyWalletFundings();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _wallet = w;
          _userRole = me.role;
          _fiatTraceRows = trace;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showRegisterWalletDialog() async {
    final ctrl = TextEditingController(
      text: _wallet?.hederaAccountId ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _blue.withAlpha(80)),
        ),
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: _cyan, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Hedera Wallet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your Hedera account ID to receive Arena Coins and NFT certificates.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Account ID  (e.g. 0.0.123456)',
                labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                prefixIcon: Icon(Icons.tag, color: _blue, size: 18),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _blue),
                ),
                filled: true,
                fillColor: _darkBg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '⚠ Also associate token 0.0.8432088 in HashPack to receive coins.',
              style: TextStyle(color: Colors.orange.shade300, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final id = ctrl.text.trim();
              if (id.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _api.registerWallet(id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Wallet registered successfully!'),
                      backgroundColor: Color(0xFF1A3A2A),
                    ),
                  );
                  _loadWallet();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red.shade900,
                    ),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _showGenerateCertDialog() async {
    final ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purple.withAlpha(120)),
        ),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.purpleAccent, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Generate Certificate',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the hackathon name to mint your achievement NFT on Hedera.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Hackathon Name',
                labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                prefixIcon: const Icon(Icons.emoji_events, color: Colors.purpleAccent, size: 18),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.purpleAccent),
                ),
                filled: true,
                fillColor: _darkBg,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              _mintCertificate(name);
            },
            child: const Text('Mint NFT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _mintCertificate(String hackathonName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: _cardBg,
        content: Row(
          children: [
            CircularProgressIndicator(color: _cyan),
            SizedBox(width: 20),
            Text('Minting NFT on Hedera...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      final result = await _api.generateCertificate(hackathonName);
      if (mounted) Navigator.pop(context); // close loading

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.purpleAccent),
            ),
            title: const Row(
              children: [
                Icon(Icons.verified, color: Colors.purpleAccent),
                SizedBox(width: 10),
                Text('Certificate Minted!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Token ID', result['tokenId']?.toString() ?? '-'),
                _infoRow('Serial #', result['serialNumber']?.toString() ?? '-'),
                if (result['ipfsUrl'] != null)
                  _infoRow('IPFS', result['ipfsUrl']?.toString() ?? '-'),
                if (result['transferStatus'] != null)
                  _infoRow('Transfer', result['transferStatus']?.toString() ?? '-'),
              ],
            ),
            actions: [
              if (result['hashScanUrl'] != null)
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16, color: _cyan),
                  label: const Text('View on HashScan', style: TextStyle(color: _cyan)),
                  onPressed: () async {
                    final uri = Uri.tryParse(result['hashScanUrl'] as String);
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _blue),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade900),
        );
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          // Grid background (same as profile)
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          RefreshIndicator(
            onRefresh: _loadWallet,
            color: _cyan,
            backgroundColor: _cardBg,
            child: CustomScrollView(
              slivers: [
                // ── App Bar ──
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: Icon(Icons.arrow_back, color: Colors.grey.shade400),
                          ),
                          const Expanded(
                            child: Text(
                              'ARENA WALLET',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                color: _blue,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _loadWallet,
                            icon: Icon(Icons.refresh, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_loading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: _cyan)),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _blue),
                            onPressed: _loadWallet,
                            child: const Text('Retry', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // ── Balance Card ──
                  SliverToBoxAdapter(child: _buildBalanceCard()),

                  // ── Hedera Wallet Section ──
                  SliverToBoxAdapter(child: _buildHederaSection()),

                  if (_isAdmin) SliverToBoxAdapter(child: _buildAdminMintSection()),

                  // ── Actions ──
                  SliverToBoxAdapter(child: _buildActions()),

                  if (_userRole == 'COMPANY')
                    SliverToBoxAdapter(child: _buildFiatTraceSection()),

                  // ── Transaction History ──
                  SliverToBoxAdapter(child: _buildHistoryHeader()),

                  if (_wallet!.transactions.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyTx())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildTxRow(_wallet!.transactions[i]),
                        childCount: _wallet!.transactions.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Balance Card ───────────────────────────────────────────────

  Widget _buildBalanceCard() {
    final balance = _wallet?.walletBalance ?? 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D2952), Color(0xFF091428)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _blue.withAlpha(80)),
          boxShadow: [
            BoxShadow(color: _blue.withAlpha(40), blurRadius: 30, spreadRadius: -5),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, _) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _cyan,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: _cyan.withAlpha((_pulseAnim.value * 200).round()), blurRadius: 10),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ARENA COIN BALANCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  balance.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _cyan.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _cyan.withAlpha(80)),
                    ),
                    child: const Text(
                      'ARENA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _cyan,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_wallet?.tokenId != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.link, color: Colors.grey.shade500, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Token: ${_wallet!.tokenId}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Hedera Section ─────────────────────────────────────────────

  Widget _buildHederaSection() {
    final hasWallet = _wallet?.hederaAccountId != null && _wallet!.hederaAccountId!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(13)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HEDERA ACCOUNT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            if (hasWallet) ...[
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A3C4).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Color(0xFF00A3C4), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Linked Account', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          _wallet!.hederaAccountId!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _wallet!.hederaAccountId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account ID copied!')),
                      );
                    },
                    child: Icon(Icons.copy, color: Colors.grey.shade500, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_wallet?.hashScanUrl != null)
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.tryParse(_wallet!.hashScanUrl!);
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 13, color: _cyan),
                      const SizedBox(width: 4),
                      Text('View on HashScan Testnet', style: TextStyle(color: _cyan, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No Hedera wallet linked. Link one to receive coins & NFTs.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(hasWallet ? Icons.edit : Icons.link, size: 16),
                label: Text(hasWallet ? 'Change Wallet' : 'Link Hedera Wallet'),
                onPressed: _showRegisterWalletDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cyan,
                  side: BorderSide(color: _cyan.withAlpha(120)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminMintSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withAlpha(60)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.amber.shade200, size: 20),
                const SizedBox(width: 8),
                Text(
                  'ADMIN — ENVOYER DES ARENA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Colors.amber.shade200,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Mint depuis le trésor vers le compte Hedera lié de l’utilisateur. Saisissez l’ID Hedera (pas l’ID MongoDB).',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _adminMintHederaController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'ID compte Hedera destinataire',
                hintText: '0.0.123456',
                labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                prefixIcon: Icon(Icons.account_balance_wallet, color: Colors.amber.shade200, size: 18),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.amber.shade200),
                ),
                filled: true,
                fillColor: _darkBg,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminMintAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Montant (ARENA)',
                hintText: 'ex. 10 ou 10.5',
                labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                prefixIcon: Icon(Icons.monetization_on_outlined, color: Colors.amber.shade200, size: 18),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.amber.shade200),
                ),
                filled: true,
                fillColor: _darkBg,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _adminMintBusy ? null : _runAdminMintFlow,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _adminMintBusy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Envoyer ARENA', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Action Buttons ──────────────────────────────────────────────

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _actionCard(
              icon: Icons.workspace_premium,
              label: 'Generate\nCertificate',
              color: Colors.purpleAccent,
              onTap: _showGenerateCertDialog,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionCard(
              icon: Icons.history,
              label: 'Refresh\nHistory',
              color: _blue,
              onTap: _loadWallet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(60)),
          boxShadow: [BoxShadow(color: color.withAlpha(20), blurRadius: 16)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Crédits admin avec traçabilité paiement → Arena Coins (entreprises)
  Widget _buildFiatTraceSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRAÇABILITÉ CRÉDITS (FIAT → ARENA)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 12),
          if (_fiatTraceRows.isEmpty)
            Text(
              'Aucune entrée enregistrée par la plateforme.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            )
          else
            ..._fiatTraceRows.map((row) {
              final m = row as Map<String, dynamic>;
              final ref = m['paymentReference'] as String? ?? '';
              final amt = m['arenaCoinAmount'];
              final pm = m['paymentMethod'] as String? ?? '';
              final anchor = m['proofHederaAnchorTxId'] as String?;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cyan.withAlpha(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+ $amt ARENA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$pm · Réf. $ref',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    if (anchor != null && anchor.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(
                              'https://hashscan.io/testnet/transaction/$anchor',
                            );
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.link, size: 16, color: _cyan),
                          label: const Text(
                            'Preuve ancrée Hedera (hash)',
                            style: TextStyle(color: _cyan, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Transaction History ─────────────────────────────────────────

  Widget _buildHistoryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'TRANSACTION HISTORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Colors.grey.shade500,
            ),
          ),
          if (_wallet != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _blue.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_wallet!.transactions.length} records',
                style: const TextStyle(fontSize: 11, color: _blue, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyTx() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade700),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Arena Coin movements will appear here.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTxRow(TransactionLog tx) {
    final isCredit = tx.isCredit;
    final isPending = tx.isPending;
    final isFailed = tx.isFailed;

    Color statusColor;
    if (isFailed) {
      statusColor = Colors.red.shade400;
    } else if (isPending) {
      statusColor = Colors.orange.shade400;
    } else if (isCredit) {
      statusColor = const Color(0xFF22C55E);
    } else {
      statusColor = Colors.red.shade300;
    }

    final amountStr = '${isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(2)} ARENA';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFailed
                ? Colors.red.withAlpha(40)
                : isPending
                    ? Colors.orange.withAlpha(40)
                    : isCredit
                        ? const Color(0xFF22C55E).withAlpha(30)
                        : Colors.red.withAlpha(30),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_txIcon(tx.type), color: statusColor, size: 20),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.typeLabel,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(tx.createdAt),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                  if (isPending)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '⏳ Associate token in HashPack to receive',
                        style: TextStyle(color: Colors.orange.shade400, fontSize: 11),
                      ),
                    )
                  else if (isFailed && tx.errorNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        tx.errorNote!,
                        style: TextStyle(color: Colors.red.shade400, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountStr,
                  style: TextStyle(
                    color: isFailed ? Colors.grey : statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                _statusBadge(tx.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _txIcon(String type) {
    switch (type) {
      case 'ADMIN_MINT':
        return Icons.add_circle;
      case 'ESCROW_LOCK':
        return Icons.lock_outline;
      case 'REWARD_RELEASE':
        return Icons.emoji_events;
      case 'REFUND':
        return Icons.replay;
      default:
        return Icons.swap_horiz;
    }
  }

  Widget _statusBadge(String status) {
    Color c;
    String label;
    switch (status) {
      case 'SUCCESS':
        c = const Color(0xFF22C55E);
        label = 'SUCCESS';
        break;
      case 'PENDING_ASSOCIATION':
        c = Colors.orange;
        label = 'PENDING';
        break;
      default:
        c = Colors.red;
        label = 'FAILED';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}  ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _AdminMintCountdownDialog extends StatefulWidget {
  final String displayName;
  final String hederaAccountId;
  final double amount;

  const _AdminMintCountdownDialog({
    required this.displayName,
    required this.hederaAccountId,
    required this.amount,
  });

  @override
  State<_AdminMintCountdownDialog> createState() => _AdminMintCountdownDialogState();
}

class _AdminMintCountdownDialogState extends State<_AdminMintCountdownDialog> {
  static const _totalSeconds = 10;
  int _remaining = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining > 0) _remaining--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _remaining == 0;
    final amt = widget.amount.toStringAsFixed(2);
    return AlertDialog(
      backgroundColor: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.amber.withAlpha(100)),
      ),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade300, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Confirmer l’envoi',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Envoyer $amt ARENA à ${widget.displayName} ?',
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            'Wallet: ${widget.hederaAccountId}',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (!canSend)
            Text(
              'Confirmation possible dans $_remaining s…',
              style: TextStyle(color: Colors.amber.shade200, fontWeight: FontWeight.w700, fontSize: 14),
            )
          else
            Text(
              'Vous pouvez confirmer.',
              style: TextStyle(color: Colors.greenAccent.shade200, fontWeight: FontWeight.w600, fontSize: 13),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Annuler', style: TextStyle(color: Colors.grey.shade400)),
        ),
        FilledButton(
          onPressed: canSend ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
          child: Text(canSend ? 'Envoyer' : 'Patienter…'),
        ),
      ],
    );
  }
}

// ── Subtle grid background painter (same style as ProfileScreen) ──
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D6CF2).withAlpha(8)
      ..strokeWidth = 0.5;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
