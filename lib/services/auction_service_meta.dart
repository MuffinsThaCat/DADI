import 'package:flutter/foundation.dart';
import '../contracts/meta_transaction_relayer.dart';
import 'wallet_service_interface.dart';
import 'transaction_websocket_service.dart';

/// Service for interacting with the auction contract using meta-transactions
/// This allows users to participate in auctions without paying gas fees
class AuctionServiceMeta {
  final MetaTransactionRelayer _relayer;
  final WalletServiceInterface _walletService;
  final String _auctionContractAddress;
  
  // Avalanche-specific configuration
  final String _domainName;
  final String _domainVersion;
  final String _typeName;
  final String _typeSuffixData;
  final String _trustedForwarderAddress;
  
  /// Constructor
  AuctionServiceMeta({
    required MetaTransactionRelayer relayer,
    required WalletServiceInterface walletService,
    required String auctionContractAddress,
    required String domainName,
    required String domainVersion,
    required String typeName,
    required String typeSuffixData,
    required String trustedForwarderAddress,
  }) : _relayer = relayer,
       _walletService = walletService,
       _auctionContractAddress = auctionContractAddress,
       _domainName = domainName,
       _domainVersion = domainVersion,
       _typeName = typeName,
       _typeSuffixData = typeSuffixData,
       _trustedForwarderAddress = trustedForwarderAddress;
  
  /// Place a bid on an auction using a meta-transaction
  /// The gas fee will be paid by the relayer
  Future<String> placeBid({
    required String deviceId,
    required double bidAmount,
    Function(TransactionStatusUpdate)? onStatusUpdate,
  }) async {
    if (!_walletService.isUnlocked) {
      throw Exception('Wallet must be unlocked to place a bid');
    }
    
    try {
      // Check if user has quota available
      final hasQuota = await _relayer.checkQuotaAvailable(
        walletService: _walletService,
      );
      
      if (!hasQuota) {
        throw Exception('Meta-transaction quota exceeded');
      }
      
      // Convert bid amount to wei (assuming bidAmount is in ETH)
      final bidAmountWei = BigInt.from(bidAmount * 1e18);
      
      // Execute the bid function via meta-transaction
      return await _relayer.executeFunction(
        targetContract: _auctionContractAddress,
        functionSignature: 'placeBid(bytes32,uint256)',
        functionParams: [
          deviceId,
          bidAmountWei.toString(),
        ],
        domainName: _domainName,
        domainVersion: _domainVersion,
        typeName: _typeName,
        typeSuffixData: _typeSuffixData,
        trustedForwarderAddress: _trustedForwarderAddress,
        onStatusUpdate: onStatusUpdate,
      );
    } catch (e) {
      debugPrint('Error placing bid via meta-transaction: ${e.toString()}');
      throw Exception('Failed to place bid: ${e.toString()}');
    }
  }
  
  /// Finalize an auction using a meta-transaction
  Future<String> finalizeAuction({
    required String deviceId,
    Function(TransactionStatusUpdate)? onStatusUpdate,
  }) async {
    if (!_walletService.isUnlocked) {
      throw Exception('Wallet must be unlocked to finalize an auction');
    }
    
    try {
      // Check if user has quota available
      final hasQuota = await _relayer.checkQuotaAvailable(
        walletService: _walletService,
      );
      
      if (!hasQuota) {
        throw Exception('Meta-transaction quota exceeded');
      }
      
      // Execute the finalize function via meta-transaction
      return await _relayer.executeFunction(
        targetContract: _auctionContractAddress,
        functionSignature: 'finalizeAuction(bytes32)',
        functionParams: [deviceId],
        domainName: _domainName,
        domainVersion: _domainVersion,
        typeName: _typeName,
        typeSuffixData: _typeSuffixData,
        trustedForwarderAddress: _trustedForwarderAddress,
        onStatusUpdate: onStatusUpdate,
      );
    } catch (e) {
      debugPrint('Error finalizing auction via meta-transaction: ${e.toString()}');
      throw Exception('Failed to finalize auction: ${e.toString()}');
    }
  }
  
  /// Create a new auction using a meta-transaction
  Future<String> createAuction({
    required String deviceId,
    required double reservePrice,
    required int duration,
    Function(TransactionStatusUpdate)? onStatusUpdate,
  }) async {
    if (!_walletService.isUnlocked) {
      throw Exception('Wallet must be unlocked to create an auction');
    }
    
    try {
      // Check if user has quota available
      final hasQuota = await _relayer.checkQuotaAvailable(
        walletService: _walletService,
      );
      
      if (!hasQuota) {
        throw Exception('Meta-transaction quota exceeded');
      }
      
      // Convert reserve price to wei (assuming reservePrice is in ETH)
      final reservePriceWei = BigInt.from(reservePrice * 1e18);
      
      // Execute the create auction function via meta-transaction
      return await _relayer.executeFunction(
        targetContract: _auctionContractAddress,
        functionSignature: 'createAuction(bytes32,uint256,uint256)',
        functionParams: [
          deviceId,
          reservePriceWei.toString(),
          duration.toString(),
        ],
        domainName: _domainName,
        domainVersion: _domainVersion,
        typeName: _typeName,
        typeSuffixData: _typeSuffixData,
        trustedForwarderAddress: _trustedForwarderAddress,
        onStatusUpdate: onStatusUpdate,
      );
    } catch (e) {
      debugPrint('Error creating auction via meta-transaction: ${e.toString()}');
      throw Exception('Failed to create auction: ${e.toString()}');
    }
  }
  
  /// Cancel an auction using a meta-transaction
  Future<String> cancelAuction({
    required String deviceId,
    Function(TransactionStatusUpdate)? onStatusUpdate,
  }) async {
    if (!_walletService.isUnlocked) {
      throw Exception('Wallet must be unlocked to cancel an auction');
    }
    
    try {
      // Check if user has quota available
      final hasQuota = await _relayer.checkQuotaAvailable(
        walletService: _walletService,
      );
      
      if (!hasQuota) {
        throw Exception('Meta-transaction quota exceeded');
      }
      
      // Execute the cancel auction function via meta-transaction
      return await _relayer.executeFunction(
        targetContract: _auctionContractAddress,
        functionSignature: 'cancelAuction(bytes32)',
        functionParams: [deviceId],
        domainName: _domainName,
        domainVersion: _domainVersion,
        typeName: _typeName,
        typeSuffixData: _typeSuffixData,
        trustedForwarderAddress: _trustedForwarderAddress,
        onStatusUpdate: onStatusUpdate,
      );
    } catch (e) {
      debugPrint('Error canceling auction via meta-transaction: ${e.toString()}');
      throw Exception('Failed to cancel auction: ${e.toString()}');
    }
  }
  
  /// Get transaction status updates for a specific transaction
  Stream<TransactionStatusUpdate>? getTransactionStatusStream(String txHash) {
    return _relayer.getTransactionStatusStream(txHash);
  }
  
  /// Get transaction status updates for all transactions from a specific user
  Stream<TransactionStatusUpdate>? getUserTransactionStatusStream(String userAddress) {
    return _relayer.getUserTransactionStatusStream(userAddress);
  }
  
  /// Stop watching a specific transaction
  void unwatchTransaction(String txHash) {
    _relayer.unwatchTransaction(txHash);
  }
  
  /// Stop watching all transactions for a specific user
  void unwatchUserTransactions(String userAddress) {
    _relayer.unwatchUserTransactions(userAddress);
  }
}
