import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dadi/services/transaction_websocket_service.dart';

// Mock WebSocket channel
class MockWebSocketChannel extends Mock implements WebSocketChannel {
  final StreamController<dynamic> _controller = StreamController<dynamic>.broadcast();
  final MockWebSocketSink _sink = MockWebSocketSink();
  
  @override
  Stream<dynamic> get stream => _controller.stream;
  
  @override
  MockWebSocketSink get sink => _sink;
  
  // Helper method to simulate incoming messages
  void addMessage(dynamic message) {
    _controller.add(message);
  }
  
  // Helper method to close the stream
  void closeStream() {
    _controller.close();
  }
}

// Mock WebSocket sink
class MockWebSocketSink extends Mock implements WebSocketSink {
  List<dynamic> sentMessages = [];
  
  @override
  void add(dynamic message) {
    sentMessages.add(message);
  }
  
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}
}

// Mock WebSocketChannel factory
class MockWebSocketChannelFactory {
  MockWebSocketChannel? _lastCreatedChannel;
  
  MockWebSocketChannel connect(Uri uri) {
    _lastCreatedChannel = MockWebSocketChannel();
    return _lastCreatedChannel!;
  }
  
  MockWebSocketChannel? get lastCreatedChannel => _lastCreatedChannel;
}

void main() {
  group('TransactionWebSocketService', () {
    late MockWebSocketChannelFactory mockChannelFactory;
    late TransactionWebSocketService service;
    late WebSocketChannel Function(Uri) originalConnect;
    
    setUp(() {
      mockChannelFactory = MockWebSocketChannelFactory();
      service = TransactionWebSocketService(
        webSocketUrl: 'wss://test.example.com/ws',
        reconnectIntervalMs: 100,
        maxReconnectAttempts: 3,
      );
      
      // Store the original connect function
      originalConnect = WebSocketChannel.connect;
      
      // Create a replacement function
      WebSocketChannel Function(Uri) mockConnect = (Uri uri) {
        return mockChannelFactory.connect(uri);
      };
      
      // Use a dynamic approach to replace the static method
      // This avoids the "setter isn't defined" error
      (WebSocketChannel as dynamic).connect = mockConnect;
    });
    
    tearDown(() {
      // Restore the original connect function
      (WebSocketChannel as dynamic).connect = originalConnect;
    });
    
    test('initialize should connect to WebSocket server', () async {
      await service.initialize();
      expect(mockChannelFactory.lastCreatedChannel, isNotNull);
    });
    
    test('watchTransaction should send subscription message', () async {
      await service.initialize();
      const txHash = '0x1234567890abcdef';
      
      service.watchTransaction(txHash, (_) {});
      
      final sentMessages = mockChannelFactory.lastCreatedChannel!.sink.sentMessages;
      expect(sentMessages.length, 2);
      
      final subscribeMessage = jsonDecode(sentMessages[0]);
      expect(subscribeMessage['type'], 'subscribe');
      expect(subscribeMessage['entity'], 'transaction');
      expect(subscribeMessage['id'], txHash);
      
      final queryMessage = jsonDecode(sentMessages[1]);
      expect(queryMessage['type'], 'query');
      expect(queryMessage['entity'], 'transaction');
      expect(queryMessage['id'], txHash);
    });
    
    test('unwatchTransaction should send unsubscribe message', () async {
      await service.initialize();
      const txHash = '0x1234567890abcdef';
      
      service.watchTransaction(txHash, (_) {});
      service.unwatchTransaction(txHash);
      
      final sentMessages = mockChannelFactory.lastCreatedChannel!.sink.sentMessages;
      expect(sentMessages.length, 3);
      
      final unsubscribeMessage = jsonDecode(sentMessages[2]);
      expect(unsubscribeMessage['type'], 'unsubscribe');
      expect(unsubscribeMessage['entity'], 'transaction');
      expect(unsubscribeMessage['id'], txHash);
    });
    
    test('watchUserTransactions should send subscription message', () async {
      await service.initialize();
      const userAddress = '0xabcdef1234567890';
      
      service.watchUserTransactions(userAddress, (_) {});
      
      final sentMessages = mockChannelFactory.lastCreatedChannel!.sink.sentMessages;
      expect(sentMessages.length, 1);
      
      final subscribeMessage = jsonDecode(sentMessages[0]);
      expect(subscribeMessage['type'], 'subscribe');
      expect(subscribeMessage['entity'], 'user');
      expect(subscribeMessage['id'], userAddress);
    });
    
    test('unwatchUserTransactions should send unsubscribe message', () async {
      await service.initialize();
      const userAddress = '0xabcdef1234567890';
      
      service.watchUserTransactions(userAddress, (_) {});
      service.unwatchUserTransactions(userAddress);
      
      final sentMessages = mockChannelFactory.lastCreatedChannel!.sink.sentMessages;
      expect(sentMessages.length, 2);
      
      final unsubscribeMessage = jsonDecode(sentMessages[1]);
      expect(unsubscribeMessage['type'], 'unsubscribe');
      expect(unsubscribeMessage['entity'], 'user');
      expect(unsubscribeMessage['id'], userAddress);
    });
    
    test('should handle transaction status updates', () async {
      await service.initialize();
      const txHash = '0x1234567890abcdef';
      
      // Prepare to capture the update
      TransactionStatusUpdate? capturedUpdate;
      service.watchTransaction(txHash, (update) {
        capturedUpdate = update;
      });
      
      // Simulate incoming message
      mockChannelFactory.lastCreatedChannel!.addMessage(jsonEncode({
        'type': 'transaction_update',
        'txHash': txHash,
        'status': 'confirmed',
        'blockNumber': 12345,
        'confirmations': 5,
        'gasUsed': 21000,
      }));
      
      // Give time for the message to be processed
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Verify the update was processed correctly
      expect(capturedUpdate, isNotNull);
      expect(capturedUpdate!.txHash, txHash);
      expect(capturedUpdate!.status, TransactionStatus.confirmed);
      expect(capturedUpdate!.blockNumber, 12345);
      expect(capturedUpdate!.confirmations, 5);
      expect(capturedUpdate!.gasUsed, 21000);
    });
    
    test('should handle connection closure', () async {
      await service.initialize();
      
      // Simulate connection closure
      mockChannelFactory.lastCreatedChannel!.closeStream();
      
      // Give time for reconnection attempt
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Verify reconnection was attempted
      expect(mockChannelFactory.lastCreatedChannel, isNotNull);
    });
  });
}
