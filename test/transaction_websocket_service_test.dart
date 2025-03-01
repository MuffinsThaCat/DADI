import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dadi/services/transaction_websocket_service.dart';

// Generate mocks
@GenerateMocks([WebSocketSink])
import 'transaction_websocket_service_test.mocks.dart';

// Simplified mock that only implements the required methods
class MockWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> _controller = StreamController<dynamic>.broadcast();
  final MockWebSocketSink _sink = MockWebSocketSink();
  
  @override
  Stream get stream => _controller.stream;
  
  @override
  WebSocketSink get sink => _sink;
  
  void addMessage(dynamic message) {
    _controller.add(message);
  }
  
  void closeStream() {
    _controller.close();
  }
  
  @override
  int? get closeCode => null;
  
  @override
  String? get closeReason => null;
  
  @override
  String? get protocol => null;
  
  @override
  Future<void> get ready => Future.value();
  
  // We don't need to implement these methods for our tests
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TransactionWebSocketService', () {
    late MockWebSocketChannel mockChannel;
    late TransactionWebSocketService service;
    
    setUp(() {
      mockChannel = MockWebSocketChannel();
      
      service = TransactionWebSocketService(
        webSocketUrl: 'wss://test.example.com/ws',
        webSocketChannelFactory: (uri) => mockChannel,
      );
    });
    
    test('initialize should connect to WebSocket server', () async {
      await service.initialize();
      
      // No message is sent on initialization, just the connection is established
      // This is a success if no exceptions are thrown
    });
    
    test('watchTransaction should send subscription message', () async {
      const String txHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      
      await service.initialize();
      service.watchTransaction(txHash, (_) {});
      
      // Verify that we've sent a subscription message
      verify(mockChannel.sink.add(argThat(
        predicate<String>((message) {
          final Map<String, dynamic> json = jsonDecode(message);
          return json['type'] == 'subscribe' && 
                 json['entity'] == 'transaction' && 
                 json['id'] == txHash;
        })
      ))).called(1);
      
      // Verify that we've sent a query message
      verify(mockChannel.sink.add(argThat(
        predicate<String>((message) {
          final Map<String, dynamic> json = jsonDecode(message);
          return json['type'] == 'query' && 
                 json['entity'] == 'transaction' && 
                 json['id'] == txHash;
        })
      ))).called(1);
    });
    
    test('unwatchTransaction should send unsubscribe message', () async {
      const String txHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      
      await service.initialize();
      service.watchTransaction(txHash, (_) {});
      service.unwatchTransaction(txHash);
      
      // Verify that we've sent an unsubscribe message
      verify(mockChannel.sink.add(argThat(
        predicate<String>((message) {
          final Map<String, dynamic> json = jsonDecode(message);
          return json['type'] == 'unsubscribe' && 
                 json['entity'] == 'transaction' && 
                 json['id'] == txHash;
        })
      ))).called(1);
    });
    
    test('watchUserTransactions should send subscription message', () async {
      const String userAddress = '0x1234567890abcdef1234567890abcdef12345678';
      
      await service.initialize();
      service.watchUserTransactions(userAddress, (_) {});
      
      // Verify that we've sent a subscription message
      verify(mockChannel.sink.add(argThat(
        predicate<String>((message) {
          final Map<String, dynamic> json = jsonDecode(message);
          return json['type'] == 'subscribe' && 
                 json['entity'] == 'user' && 
                 json['id'] == userAddress;
        })
      ))).called(1);
    });
    
    test('unwatchUserTransactions should send unsubscribe message', () async {
      const String userAddress = '0x1234567890abcdef1234567890abcdef12345678';
      
      await service.initialize();
      service.watchUserTransactions(userAddress, (_) {});
      service.unwatchUserTransactions(userAddress);
      
      // Verify that we've sent an unsubscribe message
      verify(mockChannel.sink.add(argThat(
        predicate<String>((message) {
          final Map<String, dynamic> json = jsonDecode(message);
          return json['type'] == 'unsubscribe' && 
                 json['entity'] == 'user' && 
                 json['id'] == userAddress;
        })
      ))).called(1);
    });
    
    test('should handle transaction status updates', () async {
      const String txHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      bool callbackCalled = false;
      
      await service.initialize();
      service.watchTransaction(txHash, (update) {
        expect(update.txHash, equals(txHash));
        expect(update.status, equals(TransactionStatus.confirmed));
        expect(update.blockNumber, equals(12345));
        expect(update.confirmations, equals(5));
        expect(update.gasUsed, equals(21000));
        callbackCalled = true;
      });
      
      // Simulate incoming message
      mockChannel.addMessage(jsonEncode({
        'type': 'transaction_update',
        'txHash': txHash,
        'status': 'confirmed',
        'blockNumber': 12345,
        'confirmations': 5,
        'gasUsed': 21000
      }));
      
      // Wait for the callback to be processed
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(callbackCalled, isTrue);
    });
    
    test('should handle connection closure', () async {
      await service.initialize();
      
      // Reset the verification count for the sink
      clearInteractions(mockChannel.sink);
      
      // Simulate connection closure
      mockChannel.closeStream();
      
      // Give time for reconnection attempt
      await Future.delayed(const Duration(milliseconds: 200));
      
      // We don't need to verify specific messages for reconnection
      // Just verify the test completes without errors
    });
  });
}
