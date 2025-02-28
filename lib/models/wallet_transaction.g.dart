// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WalletTransaction _$WalletTransactionFromJson(Map<String, dynamic> json) =>
    WalletTransaction(
      hash: json['hash'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      value: (json['value'] as num).toDouble(),
      gasPrice: (json['gasPrice'] as num).toDouble(),
      gasUsed: (json['gasUsed'] as num?)?.toInt(),
      status: $enumDecode(_$TransactionStatusEnumMap, json['status']),
      type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      contractAddress: json['contractAddress'] as String?,
      functionName: json['functionName'] as String?,
      blockNumber: (json['blockNumber'] as num?)?.toInt(),
    );

Map<String, dynamic> _$WalletTransactionToJson(WalletTransaction instance) =>
    <String, dynamic>{
      'hash': instance.hash,
      'from': instance.from,
      'to': instance.to,
      'value': instance.value,
      'gasPrice': instance.gasPrice,
      'gasUsed': instance.gasUsed,
      'status': _$TransactionStatusEnumMap[instance.status]!,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'contractAddress': instance.contractAddress,
      'functionName': instance.functionName,
      'blockNumber': instance.blockNumber,
    };

const _$TransactionStatusEnumMap = {
  TransactionStatus.pending: 'pending',
  TransactionStatus.confirmed: 'confirmed',
  TransactionStatus.failed: 'failed',
};

const _$TransactionTypeEnumMap = {
  TransactionType.send: 'send',
  TransactionType.receive: 'receive',
  TransactionType.contractCall: 'contractCall',
};
