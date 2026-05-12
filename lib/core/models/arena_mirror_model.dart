class ArenaMirrorTransactionsPage {
  final String source;
  final String strategy;
  final String mirrorBaseUrl;
  final String treasuryAccountId;
  final String tokenId;
  final int decimals;
  final List<ArenaMirrorTransactionItem> transactions;
  final String? next;

  ArenaMirrorTransactionsPage({
    required this.source,
    required this.strategy,
    required this.mirrorBaseUrl,
    required this.treasuryAccountId,
    required this.tokenId,
    required this.decimals,
    required this.transactions,
    required this.next,
  });

  factory ArenaMirrorTransactionsPage.fromJson(Map<String, dynamic> json) {
    final links = json['links'] as Map<String, dynamic>?;
    return ArenaMirrorTransactionsPage(
      source: json['source'] as String? ?? 'hedera-mirror',
      strategy: json['strategy'] as String? ?? '',
      mirrorBaseUrl: json['mirrorBaseUrl'] as String? ?? '',
      treasuryAccountId: json['treasuryAccountId'] as String? ?? '',
      tokenId: json['tokenId'] as String? ?? '',
      decimals: json['decimals'] as int? ?? 2,
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => ArenaMirrorTransactionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      next: links?['next'] as String?,
    );
  }
}

class ArenaMirrorTransactionItem {
  final String? transactionId;
  final String consensusTimestamp;
  final String consensusAtIso;
  final String? type;
  final String? result;
  final List<ArenaMirrorTransferLeg> transfers;
  final List<ArenaMirrorRawLeg> rawTokenLegs;

  ArenaMirrorTransactionItem({
    required this.transactionId,
    required this.consensusTimestamp,
    required this.consensusAtIso,
    required this.type,
    required this.result,
    required this.transfers,
    required this.rawTokenLegs,
  });

  factory ArenaMirrorTransactionItem.fromJson(Map<String, dynamic> json) {
    return ArenaMirrorTransactionItem(
      transactionId: json['transactionId'] as String?,
      consensusTimestamp: json['consensusTimestamp'] as String? ?? '',
      consensusAtIso: json['consensusAtIso'] as String? ?? '',
      type: json['type'] as String?,
      result: json['result'] as String?,
      transfers: (json['transfers'] as List<dynamic>? ?? [])
          .map((e) => ArenaMirrorTransferLeg.fromJson(e as Map<String, dynamic>))
          .toList(),
      rawTokenLegs: (json['rawTokenLegs'] as List<dynamic>? ?? [])
          .map((e) => ArenaMirrorRawLeg.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ArenaMirrorTransferLeg {
  final String sender;
  final String receiver;
  final double amount;
  final String amountRaw;

  ArenaMirrorTransferLeg({
    required this.sender,
    required this.receiver,
    required this.amount,
    required this.amountRaw,
  });

  factory ArenaMirrorTransferLeg.fromJson(Map<String, dynamic> json) {
    return ArenaMirrorTransferLeg(
      sender: json['sender'] as String? ?? '',
      receiver: json['receiver'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      amountRaw: json['amountRaw'] as String? ?? '',
    );
  }
}

class ArenaMirrorRawLeg {
  final String account;
  final double amount;
  final String amountRaw;

  ArenaMirrorRawLeg({
    required this.account,
    required this.amount,
    required this.amountRaw,
  });

  factory ArenaMirrorRawLeg.fromJson(Map<String, dynamic> json) {
    return ArenaMirrorRawLeg(
      account: json['account'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      amountRaw: json['amountRaw'] as String? ?? '',
    );
  }
}
