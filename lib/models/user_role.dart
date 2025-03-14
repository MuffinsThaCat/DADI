import 'package:flutter/material.dart';

/// Defines the roles that users can have in the DADI platform
enum UserRole {
  /// Regular user who can bid on auctions
  user,
  
  /// Creator/streamer who can create auctions and control devices
  creator
}

/// Extension methods for UserRole
extension UserRoleExtension on UserRole {
  /// Returns true if this role can create auctions
  bool get canCreateAuctions => this == UserRole.creator;
  
  /// Returns true if this role can bid on auctions
  bool get canBidOnAuctions => true; // All roles can bid
  
  /// Returns a human-readable display name for this role
  String get displayName {
    switch (this) {
      case UserRole.user:
        return 'User';
      case UserRole.creator:
        return 'Creator';
    }
  }
  
  /// Returns an icon for this role
  IconData get icon {
    switch (this) {
      case UserRole.user:
        return Icons.person;
      case UserRole.creator:
        return Icons.videocam;
    }
  }
  
  /// Returns a description for this role
  String get description {
    switch (this) {
      case UserRole.user:
        return 'Bid on auctions and control devices after winning';
      case UserRole.creator:
        return 'Create auctions and allow others to control your devices';
    }
  }
}
