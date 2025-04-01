import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';

class UserProfileMenu extends StatelessWidget {
  final String username;

  const UserProfileMenu({
    super.key,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Row(
        children: [
          const Icon(CupertinoIcons.person_circle_fill, color: kPrimaryBlue),
          const SizedBox(width: 8),
          Text(
            username,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      onSelected: (value) async {
        if (value == 'profile') {
          Navigator.pushNamed(context, '/profile');
        } else if (value == 'logout') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/');
          }
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(CupertinoIcons.person, color: kPrimaryBlue),
              SizedBox(width: 8),
              Text('Profile'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(CupertinoIcons.square_arrow_right, color: kPrimaryBlue),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
        ),
      ],
    );
  }
} 