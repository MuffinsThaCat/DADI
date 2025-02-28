import 'package:json_annotation/json_annotation.dart';

part 'wallet_transaction.g.dart';

/// Transaction status
enum TransactionStatus {
  pending,
  confirmed,
  failed
}

/// Transaction type
enum TransactionType {
  send,
  receive,
  contractCall
}

/// Model representing a wallet transaction
@JsonSerializable()
class WalletTransaction {
  /// Transaction hash
  final String hash;
  
  /// From address
  final String from;
  
  /// To address
  final String to;
  
  /// Value in ETH
  final double value;
  
  /// Gas price in Gwei
  final double gasPrice;
  
  /// Gas used
  final int? gasUsed;
  
  /// Transaction status
  final TransactionStatus status;
  
  /// Transaction type
  final TransactionType type;
  
  /// Timestamp of the transaction
  final DateTime timestamp;
  
  /// Contract address (if applicable)
  final String? contractAddress;
  
  /// Function name (if applicable)
  final String? functionName;
  
  /// Block number (if confirmed)
  final int? blockNumber;
  
  WalletTransaction({
    required this.hash,
    required this.from,
    required this.to,
    required this.value,
    required this.gasPrice,
    this.gasUsed,
    required this.status,
    required this.type,
    required this.timestamp,
    this.contractAddress,
    this.functionName,
    this.blockNumber,
  });
  
  /// Create from JSON
  factory WalletTransaction.fromJson(Map<String, dynamic> json) => 
      _$WalletTransactionFromJson(json);
  
  /// Convert to JSON
  Map<String, dynamic> toJson() => _$WalletTransactionToJson(this);
}
