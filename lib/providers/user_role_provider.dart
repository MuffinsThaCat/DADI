import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_role.dart';

/// Provider for managing the user's role in the app
class UserRoleProvider extends ChangeNotifier {
  static const String _roleKey = 'user_role';
  UserRole _role = UserRole.user; // Default to user role
  bool _hasSelectedRole = false;

  UserRoleProvider() {
    _loadRole();
  }

  /// Current user role
  UserRole get role => _role;
  
  /// Whether the user has selected a role yet
  bool get hasSelectedRole => _hasSelectedRole;

  /// Set the user role
  Future<void> setRole(UserRole role) async {
    _role = role;
    _hasSelectedRole = true;
    notifyListeners();
    
    // Save to persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_roleKey, role.name);
    } catch (e) {
      debugPrint('Error saving user role: $e');
    }
  }

  /// Loads the user role from persistent storage
  Future<void> _loadRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleString = prefs.getString(_roleKey);
      
      if (roleString != null) {
        if (roleString == UserRole.creator.name) {
          _role = UserRole.creator;
        } else {
          _role = UserRole.user;
        }
        _hasSelectedRole = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user role: $e');
    }
  }

  /// Reset the role selection (for testing purposes)
  Future<void> resetRoleSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_roleKey);
      _hasSelectedRole = false;
      _role = UserRole.user;
      notifyListeners();
    } catch (e) {
      debugPrint('Error resetting user role: $e');
    }
  }
}
