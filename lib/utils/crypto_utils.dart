import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/digests/keccak.dart';

/// Utility class for encryption and decryption operations
class CryptoUtils {
  /// Encrypt data with password
  static String encryptData(String data, String password) {
    // Generate a key from the password using SHA-256
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final key = Key(Uint8List.fromList(keyBytes));
    
    // Generate a random IV
    final iv = IV.fromSecureRandom(16);
    
    // Create encrypter with AES
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    
    // Encrypt the data
    final encrypted = encrypter.encrypt(data, iv: iv);
    
    // Combine IV and encrypted data for storage
    final combined = base64.encode(iv.bytes + encrypted.bytes);
    
    return combined;
  }
  
  /// Decrypt data with password
  static String decryptData(String encryptedData, String password) {
    try {
      // Generate key from password
      final keyBytes = sha256.convert(utf8.encode(password)).bytes;
      final key = Key(Uint8List.fromList(keyBytes));
      
      // Decode the combined data
      final bytes = base64.decode(encryptedData);
      
      // Extract IV (first 16 bytes) and encrypted data
      final iv = IV(Uint8List.fromList(bytes.sublist(0, 16)));
      final encryptedBytes = Uint8List.fromList(bytes.sublist(16));
      
      // Create encrypter and decrypt
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt64(base64.encode(encryptedBytes), iv: iv);
      
      return decrypted;
    } catch (e) {
      throw Exception('Failed to decrypt data: ${e.toString()}');
    }
  }
  
  /// Generate a secure hash of a password (for verification)
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Verify a password against a hash
  static bool verifyPassword(String password, String hash) {
    final passwordHash = hashPassword(password);
    return passwordHash == hash;
  }
  
  /// Compute the Keccak-256 hash of the input
  static Uint8List keccak256(Uint8List input) {
    final keccak = KeccakDigest(256);
    final result = Uint8List(32); // 256 bits = 32 bytes
    keccak.update(input, 0, input.length);
    keccak.doFinal(result, 0);
    return result;
  }
}
