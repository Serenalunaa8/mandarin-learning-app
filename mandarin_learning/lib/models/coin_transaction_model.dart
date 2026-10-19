class CoinTransaction {
  final String id;
  final String userId;
  final String? attemptId;
  final int amount;
  final String transactionType;
  final String description;
  final DateTime createdAt;

  CoinTransaction({
    required this.id,
    required this.userId,
    this.attemptId,
    required this.amount,
    required this.transactionType,
    required this.description,
    required this.createdAt,
  });

  factory CoinTransaction.fromJson(Map<String, dynamic> json) {
    return CoinTransaction(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      attemptId: json['attempt_id']?.toString(),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      transactionType: (json['transaction_type'] ?? 'reward').toString(),
      description: (json['description'] ?? '').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'attempt_id': attemptId,
    'amount': amount,
    'transaction_type': transactionType,
    'description': description,
    'created_at': createdAt.toIso8601String(),
  };
}
