import 'package:flutter/material.dart';

mixin NavigationMixin<T extends StatefulWidget> on State<T> {
  void handleNavigation(int index, BuildContext context) {
    String currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    String targetRoute;

    switch (index) {
      case 0:
        targetRoute = '/dashboard';
        break;
      case 1:
        targetRoute = '/goals';
        break;
      case 2:
        targetRoute = '/meals';
        break;
      case 3:
        targetRoute = '/workouts';
        break;
      default:
        targetRoute = '/dashboard';
    }

    // Only navigate if we're not already on the target route
    if (currentRoute != targetRoute) {
      Navigator.pushReplacementNamed(context, targetRoute);
    }
  }

  // Helper method to determine current index based on route
  int getCurrentIndex(BuildContext context) {
    String currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    switch (currentRoute) {
      case '/dashboard':
        return 0;
      case '/goals':
        return 1;
      case '/meals':
        return 2;
      case '/workouts':
        return 3;
      default:
        return 0;
    }
  }
} 