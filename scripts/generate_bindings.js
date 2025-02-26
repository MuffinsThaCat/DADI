const fs = require('fs');
const path = require('path');

// Read the contract ABI
const contractPath = path.join(__dirname, '..', 'artifacts', 'contracts', 'DADIAuction.sol', 'DADIAuction.json');
const contract = JSON.parse(fs.readFileSync(contractPath, 'utf8'));

// Generate Dart bindings
const dartCode = `// Generated code - do not modify by hand
// This file provides the Dart interface to the DADIAuction smart contract

import 'package:web3dart/web3dart.dart';
import 'package:flutter_web3/flutter_web3.dart';

class DADIAuction {
  static const String abi = '''${JSON.stringify(contract.abi, null, 2)}''';

  final String address;
  final Web3Provider provider;
  final Contract _contract;

  DADIAuction(this.address, this.provider)
      : _contract = Contract(
          address,
          Interface(abi),
          provider.getSigner(),
        );

  // Contract functions
  Future<String> createAuction(
    String deviceId,
    BigInt startTime,
    BigInt duration,
    BigInt minBid,
  ) async {
    final tx = await _contract.createAuction(
      deviceId,
      startTime,
      duration,
      minBid,
    );
    return tx.hash;
  }

  Future<String> placeBid(String deviceId) async {
    final tx = await _contract.placeBid(deviceId);
    return tx.hash;
  }

  Future<String> finalizeAuction(String deviceId) async {
    final tx = await _contract.finalizeAuction(deviceId);
    return tx.hash;
  }

  Future<bool> hasControl(String deviceId, String controller) async {
    return await _contract.hasControl(deviceId, controller);
  }

  Future<Map<String, dynamic>> getAuction(String deviceId) async {
    final result = await _contract.getAuction(deviceId);
    return {
      'deviceOwner': result[0],
      'startTime': result[1],
      'endTime': result[2],
      'minBid': result[3],
      'highestBidder': result[4],
      'highestBid': result[5],
      'active': result[6],
    };
  }

  // Event filters
  Filter get filters => _contract.filters;

  // Event listeners
  void on(String event, Function callback) {
    _contract.on(event, callback);
  }

  Future<List<dynamic>> queryFilter(
    Filter filter,
    dynamic fromBlock,
    dynamic toBlock,
  ) async {
    return await _contract.queryFilter(filter, fromBlock, toBlock);
  }
}
`;

// Write the Dart file
const outputPath = path.join(__dirname, '..', 'lib', 'contracts', 'dadi_auction.g.dart');
fs.writeFileSync(outputPath, dartCode);
console.log('Generated Dart bindings at:', outputPath);
