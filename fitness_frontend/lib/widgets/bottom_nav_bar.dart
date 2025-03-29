import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../constants/colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: CupertinoColors.systemGrey6,
            width: 0.5,
          ),
        ),
      ),
      child: CupertinoTabBar(
        currentIndex: currentIndex,
        onTap: onTap,
        activeColor: kPrimaryBlue,
        inactiveColor: kSecondaryText,
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.8),
        iconSize: 24,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar_fill),
            label: 'Goals',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.cart_fill),
            label: 'Meals',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.sportscourt_fill),
            label: 'Workouts',
          ),
        ],
        border: Border(
          top: BorderSide(
            color: CupertinoColors.systemGrey6,
            width: 0.5,
          ),
        ),
      ),
    );
  }
} 