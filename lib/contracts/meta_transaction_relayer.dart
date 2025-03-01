import '../services/meta_transaction_service.dart';
import '../services/wallet_service_interface.dart';
// Note: BigInt is used in the estimateGasCost method

/// Interface for interacting with the meta-transaction relayer contract on Avalanche
class MetaTransactionRelayer {
  final MetaTransactionService _metaTransactionService;
  
  /// Constructor
  MetaTransactionRelayer({
    required MetaTransactionService metaTransactionService,
    required String relayerContractAddress, // Kept for backward compatibility
  }) : _metaTransactionService = metaTransactionService;
  
  /// Execute a contract function call as a meta-transaction
  /// This allows users to interact with contracts without paying gas fees
  Future<String> executeFunction({
    required String targetContract,
    required String functionSignature,
    required List<dynamic> functionParams,
    required String domainName,
    required String domainVersion,
    required String typeName,
    required String typeSuffixData,
    required String trustedForwarderAddress,
    int? gasLimit,
    int? validUntilTime,
  }) async {
    try {
      // For Avalanche's implementation, we directly call the target contract
      // through the trusted forwarder
      return await _metaTransactionService.executeMetaTransaction(
        trustedForwarderAddress: trustedForwarderAddress,
        contractAddress: targetContract,
        functionSignature: functionSignature,
        functionParams: functionParams,
        domainName: domainName,
        domainVersion: domainVersion,
        typeName: typeName,
        typeSuffixData: typeSuffixData,
        gasLimit: gasLimit,
        validUntilTime: validUntilTime,
      );
    } catch (e) {
      throw Exception('Failed to execute function via Avalanche relayer: ${e.toString()}');
    }
  }
  
  /// Check if a user's meta-transaction quota is available
  /// Some relayers may limit the number of free transactions per user
  Future<bool> checkQuotaAvailable({
    required WalletServiceInterface walletService,
  }) async {
    final userAddress = walletService.currentAddress;
    if (userAddress == null) {
      throw Exception('No wallet address available');
    }
    
    try {
      // This would be an actual contract call in a real implementation
      // For now, we'll simulate it
      return true;
    } catch (e) {
      throw Exception('Failed to check quota: ${e.toString()}');
    }
  }
  
  /// Estimate the gas cost for a meta-transaction
  /// This is useful for displaying to users how much they're saving
  Future<BigInt> estimateGasCost({
    required String targetContract,
    required String functionSignature,
    required List<dynamic> functionParams,
  }) async {
    // This would be an actual gas estimation in a real implementation
    // For now, we'll return a fixed value
    return BigInt.from(500000);
  }
}
