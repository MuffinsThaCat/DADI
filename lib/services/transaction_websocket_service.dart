import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
  
  /// Flag indicating if the WebSocket connection is active
  bool get isConnected => _channel != null;
  
  /// Flag to enable mock mode (no actual WebSocket connection)
  final bool useMockMode;
  
  /// Constructor
  TransactionWebSocketService({
    required String webSocketUrl,
    WebSocketChannel Function(Uri)? webSocketChannelFactory,
    this.useMockMode = false,
  }) : _webSocketUrl = webSocketUrl,
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
    // If in mock mode, don't actually connect to WebSocket
    if (useMockMode) {
      debugPrint('WebSocket in mock mode - not connecting to real server');
      _reconnectAttempts = 0;
      return;
    }
    
    try {
      debugPrint('Attempting to connect to WebSocket at $_webSocketUrl (attempt ${_reconnectAttempts + 1})');
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
      
      // Send a ping to verify connection
      try {
        _sendMessage({
          'type': 'ping',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        // Reset reconnect attempts on successful connection
        _reconnectAttempts = 0;
        debugPrint('Connected to transaction status WebSocket');
      } catch (e) {
        debugPrint('Failed to send initial ping: $e');
        scheduleReconnect();
      }
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      scheduleReconnect();
    }
  }

  /// Schedule a reconnection attempt with exponential backoff
  @protected
  void scheduleReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      return; // Already scheduled
    }
    
    // Calculate backoff delay (max 30 seconds)
    final delay = Duration(
      milliseconds: math.min(
        500 * math.pow(1.5, _reconnectAttempts).round(),
        30000,
      ),
    );
    
    debugPrint('Scheduling reconnect in ${delay.inMilliseconds}ms (attempt ${_reconnectAttempts + 1})');
    
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      debugPrint('Attempting to reconnect (attempt $_reconnectAttempts)');
      connectWebSocket();
    });
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
  
  /// Send a message to the WebSocket server
  void _sendMessage(Map<String, dynamic> message) {
    // In mock mode, just log the message but don't try to send it
    if (useMockMode) {
      debugPrint('Mock WebSocket: Would send message: $message');
      return;
    }
    
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

  /// Send a ping message to keep the connection alive
  @protected
  void sendPingMessage(Map<String, dynamic> pingMessage) {
    _sendMessage(pingMessage);
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

  /// Simulate a transaction status update (only for mock mode)
  /// This allows for testing and development without a real WebSocket connection
  void simulateTransactionUpdate({
    required String txHash,
    required TransactionStatus status,
    int? blockNumber,
    int? confirmations,
    String? errorMessage,
    int? gasUsed,
  }) {
    if (!useMockMode) {
      debugPrint('Warning: Attempted to simulate transaction update while not in mock mode');
      return;
    }
    
    final update = TransactionStatusUpdate(
      txHash: txHash,
      status: status,
      blockNumber: blockNumber,
      confirmations: confirmations,
      errorMessage: errorMessage,
      gasUsed: gasUsed,
      timestamp: DateTime.now(),
    );
    
    // Notify transaction-specific callbacks
    if (_txCallbacks.containsKey(txHash)) {
      _txCallbacks[txHash]!(update);
    }
    
    // Notify user callbacks (we don't know which user this transaction belongs to,
    // so we notify all user callbacks in mock mode)
    for (final callback in _userCallbacks.values) {
      callback(update);
    }
    
    debugPrint('Mock WebSocket: Simulated transaction update for $txHash: $status');
  }
}
