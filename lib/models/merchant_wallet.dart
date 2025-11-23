import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType {
  deposit,
  adSpend,
  refund;

  String get displayName {
    switch (this) {
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.adSpend:
        return 'Ad Spend';
      case TransactionType.refund:
        return 'Refund';
    }
  }
}

class WalletTransaction {
  final String id;
  final String merchantId;
  final TransactionType type;
  final double amount;
  final double balanceAfter;
  final DateTime createdAt;
  final String? adId;
  final String? description;

  WalletTransaction({
    required this.id,
    required this.merchantId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.adId,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchantId': merchantId,
      'type': type.name,
      'amount': amount,
      'balanceAfter': balanceAfter,
      'createdAt': Timestamp.fromDate(createdAt),
      'adId': adId,
      'description': description,
    };
  }

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id'] ?? '',
      merchantId: map['merchantId'] ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.deposit,
      ),
      amount: map['amount']?.toDouble() ?? 0.0,
      balanceAfter: map['balanceAfter']?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      adId: map['adId'],
      description: map['description'],
    );
  }
}

class MerchantWallet {
  final String id;
  final String userId;
  final double balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  MerchantWallet({
    required this.id,
    required this.userId,
    this.balance = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'balance': balance,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MerchantWallet.fromMap(Map<String, dynamic> map) {
    return MerchantWallet(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      balance: map['balance']?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  MerchantWallet copyWith({
    String? id,
    String? userId,
    double? balance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MerchantWallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}








