import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// Status of a meta-transaction
enum TransactionStatus {
  /// Transaction has been submitted to the relayer
  submitted,
  
  /// Transaction is being processed by the relayer
  processing,
  
  /// Transaction has been mined and confirmed on the blockchain
  confirmed,
  
  /// Transaction failed (could be relayer error or on-chain failure)
  failed,
  
  /// Transaction was dropped or replaced
  dropped,
  
  /// Transaction status is unknown
  unknown
}

/// Details of a transaction status update
class TransactionStatusUpdate {
  /// Transaction hash
  final String txHash;
  
  /// Current status of the transaction
  final TransactionStatus status;
  
  /// Block number where transaction was mined (null if not yet mined)
  final int? blockNumber;
  
  /// Number of confirmations
  final int? confirmations;
  
  /// Error message if transaction failed
  final String? errorMessage;
  
  /// Gas used by the transaction (if confirmed)
  final int? gasUsed;
  
  /// Timestamp of this status update
  final DateTime timestamp;
  
  /// Constructor
  TransactionStatusUpdate({
    required this.txHash,
    required this.status,
    this.blockNumber,
    this.confirmations,
    this.errorMessage,
    this.gasUsed,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Callback for transaction status updates
typedef TransactionStatusCallback = void Function(TransactionStatusUpdate update);

/// Service for handling WebSocket connections to the relayer
/// This service provides real-time updates on transaction status
/// but does not expose a UI component
class TransactionWebSocketService {
  /// WebSocket URL for the relayer
  final String _webSocketUrl;
  
  /// Connection retry interval in milliseconds
  final int _reconnectIntervalMs;
  
  /// Maximum number of reconnection attempts
  final int _maxReconnectAttempts;
  
  /// Factory function for creating WebSocket channels
  final WebSocketChannel Function(Uri) _webSocketChannelFactory;
  
  /// WebSocket channel
  WebSocketChannel? _channel;
  
  /// Map of transaction hash to callback
  final Map<String, TransactionStatusCallback> _txCallbacks = {};
  
  /// Map of user address to callback
  final Map<String, TransactionStatusCallback> _userCallbacks = {};
  
  /// Flag indicating if the service is initialized
  bool _isInitialized = false;
  
  /// Number of reconnection attempts
  int _reconnectAttempts = 0;
  
  /// Timer for reconnection attempts
  Timer? _reconnectTimer;
  
  /// Constructor
  TransactionWebSocketService({
    required String webSocketUrl,
    int reconnectIntervalMs = 5000,
    int maxReconnectAttempts = 10,
    WebSocketChannel Function(Uri)? webSocketChannelFactory,
  }) : _webSocketUrl = webSocketUrl,
       _reconnectIntervalMs = reconnectIntervalMs,
       _maxReconnectAttempts = maxReconnectAttempts,
       _webSocketChannelFactory = webSocketChannelFactory ?? WebSocketChannel.connect;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    
    try {
      await connectWebSocket();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize WebSocket connection: $e');
      scheduleReconnect();
    }
  }
  
  /// Dispose of the service resources
  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    await _channel?.sink.close(ws_status.normalClosure);
    
    _txCallbacks.clear();
    _userCallbacks.clear();
    
    _isInitialized = false;
  }
  
  /// Register a callback for a specific transaction
  void watchTransaction(String txHash, TransactionStatusCallback callback) {
    _txCallbacks[txHash] = callback;
    
    // Send subscription message to the server
    _sendMessage({
      'type': 'subscribe',
      'entity': 'transaction',
      'id': txHash,
    });
    
    // Query current status
    _sendMessage({
      'type': 'query',
      'entity': 'transaction',
      'id': txHash,
    });
  }
  
  /// Stop watching a specific transaction
  void unwatchTransaction(String txHash) {
    _txCallbacks.remove(txHash);
    
    // Send unsubscribe message to the server
    _sendMessage({
      'type': 'unsubscribe',
      'entity': 'transaction',
      'id': txHash,
    });
  }
  
  /// Register a callback for all transactions from a specific user
  void watchUserTransactions(String userAddress, TransactionStatusCallback callback) {
    _userCallbacks[userAddress] = callback;
    
    // Send subscription message to the server
    _sendMessage({
      'type': 'subscribe',
      'entity': 'user',
      'id': userAddress,
    });
  }
  
  /// Stop watching transactions for a specific user
  void unwatchUserTransactions(String userAddress) {
    _userCallbacks.remove(userAddress);
    
    // Send unsubscribe message to the server
    _sendMessage({
      'type': 'unsubscribe',
      'entity': 'user',
      'id': userAddress,
    });
  }
  
  /// Connect to the WebSocket server
  @protected
  Future<void> connectWebSocket() async {
    try {
      _channel = _webSocketChannelFactory(Uri.parse(_webSocketUrl));
      
      // Listen for incoming messages
      _channel!.stream.listen(
        (message) => handleWebSocketMessage(message),
        onError: (error) {
          debugPrint('WebSocket error: $error');
          scheduleReconnect();
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          scheduleReconnect();
        },
      );
      
      // Reset reconnect attempts on successful connection
      _reconnectAttempts = 0;
      debugPrint('Connected to transaction status WebSocket');
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      scheduleReconnect();
    }
  }
  
  /// Handle incoming WebSocket messages
  @protected
  void handleWebSocketMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      
      if (data['type'] == 'transaction_update') {
        final txHash = data['txHash'] as String;
        final statusStr = data['status'] as String;
        
        // Parse the status
        final status = parseTransactionStatus(statusStr);
        
        // Create the update
        final update = TransactionStatusUpdate(
          txHash: txHash,
          status: status,
          blockNumber: data['blockNumber'] as int?,
          confirmations: data['confirmations'] as int?,
          errorMessage: data['error'] as String?,
          gasUsed: data['gasUsed'] as int?,
        );
        
        // Notify transaction-specific callbacks
        if (_txCallbacks.containsKey(txHash)) {
          _txCallbacks[txHash]!(update);
        }
        
        // Notify user-specific callbacks
        final userAddress = data['userAddress'] as String?;
        if (userAddress != null && _userCallbacks.containsKey(userAddress)) {
          _userCallbacks[userAddress]!(update);
        }
      }
    } catch (e) {
      debugPrint('Error processing WebSocket message: $e');
    }
  }
  
  /// Parse transaction status string to enum
  @protected
  TransactionStatus parseTransactionStatus(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return TransactionStatus.submitted;
      case 'processing':
        return TransactionStatus.processing;
      case 'confirmed':
        return TransactionStatus.confirmed;
      case 'failed':
        return TransactionStatus.failed;
      case 'dropped':
        return TransactionStatus.dropped;
      default:
        return TransactionStatus.unknown;
    }
  }
  
  /// Schedule a reconnection attempt
  @protected
  void scheduleReconnect() {
    // Cancel any existing reconnect timer
    _reconnectTimer?.cancel();
    
    // Check if we've exceeded the maximum number of attempts
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Maximum reconnection attempts reached');
      return;
    }
    
    _reconnectAttempts++;
    
    // Schedule reconnection
    _reconnectTimer = Timer(
      Duration(milliseconds: _reconnectIntervalMs),
      () async {
        debugPrint('Attempting to reconnect (attempt $_reconnectAttempts)');
        await connectWebSocket();
      },
    );
  }
  
  /// Send a message to the WebSocket server
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel == null) {
      debugPrint('Cannot send message: WebSocket not connected');
      return;
    }
    
    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Error sending WebSocket message: $e');
    }
  }

  /// Get the WebSocket channel (for subclasses)
  @protected
  WebSocketChannel? get channel => _channel;

  /// Get transaction callbacks map (for subclasses)
  @protected
  Map<String, TransactionStatusCallback> get transactionCallbacks => _txCallbacks;

  /// Get user callbacks map (for subclasses)
  @protected
  Map<String, TransactionStatusCallback> get userCallbacks => _userCallbacks;
}
