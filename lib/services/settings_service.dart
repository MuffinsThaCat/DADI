import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  
  factory SettingsService() => _instance;
  
  SettingsService._internal();
  
  // Keys for SharedPreferences
  static const String _useMockBlockchainKey = 'useMockBlockchain';
  static const String _rpcUrlKey = 'rpcUrl';
  static const String _contractAddressKey = 'contractAddress';
  
  // Default values
  static const String _defaultRpcUrl = 'http://localhost:8087';
  static const String _defaultContractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
  
  // Cache for settings
  bool? _useMockBlockchain;
  String? _rpcUrl;
  String? _contractAddress;
  
  // Initialize settings from SharedPreferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    _useMockBlockchain = prefs.getBool(_useMockBlockchainKey) ?? kDebugMode;
    _rpcUrl = prefs.getString(_rpcUrlKey) ?? _defaultRpcUrl;
    _contractAddress = prefs.getString(_contractAddressKey) ?? _defaultContractAddress;
    
    notifyListeners();
  }
  
  // Getters
  bool getUseMockBlockchain() => _useMockBlockchain ?? kDebugMode;
  String getRpcUrl() => _rpcUrl ?? _defaultRpcUrl;
  String getContractAddress() => _contractAddress ?? _defaultContractAddress;
  
  // Setters with persistence
  Future<void> setUseMockBlockchain(bool value) async {
    if (_useMockBlockchain == value) return;
    
    _useMockBlockchain = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useMockBlockchainKey, value);
    
    notifyListeners();
  }
  
  Future<void> setRpcUrl(String value) async {
    if (_rpcUrl == value) return;
    
    _rpcUrl = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rpcUrlKey, value);
    
    notifyListeners();
  }
  
  Future<void> setContractAddress(String value) async {
    if (_contractAddress == value) return;
    
    _contractAddress = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contractAddressKey, value);
    
    notifyListeners();
  }
  
  // Reset to defaults
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_useMockBlockchainKey);
    await prefs.remove(_rpcUrlKey);
    await prefs.remove(_contractAddressKey);
    
    _useMockBlockchain = kDebugMode;
    _rpcUrl = _defaultRpcUrl;
    _contractAddress = _defaultContractAddress;
    
    notifyListeners();
  }
}
