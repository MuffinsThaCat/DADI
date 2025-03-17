import 'package:flutter/material.dart';

/// A service that provides a global navigator key for performing navigation actions
/// from anywhere in the app without requiring a BuildContext.
class NavigationService {
  /// Global navigator key used for app-wide navigation
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Navigate to a named route
  static Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(
      routeName,
      arguments: arguments,
    );
  }
  
  /// Navigate to a route and replace the current route
  static Future<dynamic> navigateToReplacement(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }
  
  /// Navigate to a route and clear the navigation stack
  static Future<dynamic> navigateToAndClearStack(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => false,
      arguments: arguments,
    );
  }
  
  /// Go back to previous screen
  static void goBack() {
    return navigatorKey.currentState!.pop();
  }
}
