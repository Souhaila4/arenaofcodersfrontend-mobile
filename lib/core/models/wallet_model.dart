// lib/core/models/wallet_model.dart
// Models for Arena Coin wallet and transaction history

class WalletInfo {
  final String userId;
  final String name;
  final double walletBalance;
  final String? hederaAccountId;
  final String? tokenId;
  final String? hashScanUrl;
  final List<TransactionLog> transactions;

  WalletInfo({
    required this.userId,
    required this.name,
    required this.walletBalance,
    this.hederaAccountId,
    this.tokenId,
    this.hashScanUrl,
    required this.transactions,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) => WalletInfo(
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
        hederaAccountId: json['hederaAccountId'] as String?,
        tokenId: json['tokenId'] as String?,
        hashScanUrl: json['hashScanUrl'] as String?,
        transactions: (json['transactions'] as List<dynamic>?)
                ?.map((e) => TransactionLog.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class TransactionLog {
  final String id;
  final String? senderAccountId;
  final String receiverAccountId;
  final double amount;
  final String tokenId;
  final String type;    // ADMIN_MINT | ESCROW_LOCK | REWARD_RELEASE | REFUND
  final String status;  // SUCCESS | FAILED | PENDING_ASSOCIATION
  final String? competitionId;
  final String? hederaTransactionId;
  final String? errorNote;
  final DateTime createdAt;

  TransactionLog({
    required this.id,
    this.senderAccountId,
    required this.receiverAccountId,
    required this.amount,
    required this.tokenId,
    required this.type,
    required this.status,
    this.competitionId,
    this.hederaTransactionId,
    this.errorNote,
    required this.createdAt,
  });

  factory TransactionLog.fromJson(Map<String, dynamic> json) => TransactionLog(
        id: json['id'] as String? ?? '',
        senderAccountId: json['senderAccountId'] as String?,
        receiverAccountId: json['receiverAccountId'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        tokenId: json['tokenId'] as String? ?? '',
        type: json['type'] as String? ?? '',
        status: json['status'] as String? ?? '',
        competitionId: json['competitionId'] as String?,
        hederaTransactionId: json['hederaTransactionId'] as String?,
        errorNote: json['errorNote'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  /// Human-readable label for the transaction type
  String get typeLabel {
    switch (type) {
      case 'ADMIN_MINT':
        return 'Coins Received';
      case 'ESCROW_LOCK':
        return 'Escrow Locked';
      case 'REWARD_RELEASE':
        return 'Reward Won';
      case 'REFUND':
        return 'Refund';
      default:
        return type;
    }
  }

  bool get isCredit =>
      type == 'ADMIN_MINT' || type == 'REWARD_RELEASE' || type == 'REFUND';
  bool get isDebit => type == 'ESCROW_LOCK';
  bool get isPending => status == 'PENDING_ASSOCIATION';
  bool get isFailed => status == 'FAILED';
}
