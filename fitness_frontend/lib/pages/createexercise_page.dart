import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/colors.dart';

class CreateExercisePage extends StatefulWidget {
  const CreateExercisePage({super.key});

  @override
  _CreateExercisePageState createState() => _CreateExercisePageState();
}

class _CreateExercisePageState extends State<CreateExercisePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _musclesController = TextEditingController();
  String? _errorMessage;

  Future<void> _createExercise() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final Map<String, dynamic> payload = {
      "name": _nameController.text.trim(),
      "description": _descriptionController.text.trim(),
      "category": _categoryController.text.trim(),
      "muscles": _musclesController.text.trim(),
      "is_predefined": true,
    };

    final response = await http.post(
      Uri.parse('http://localhost:8000/exercise_types'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );

    if (response.statusCode == 200) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          content: const Text("Exercise created successfully!"),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.pop(context); // Dismiss dialog
                Navigator.pop(context, true); // Return to workouts page
              },
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _errorMessage = json.decode(response.body)['detail'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kBackgroundColor,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: Colors.transparent,
        border: null,
        middle: Text(
          'Create Exercise',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: CupertinoColors.destructiveRed),
                    ),
                  ),

                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CupertinoColors.systemGrey4),
                  ),
                  child: CupertinoTextField(
                    controller: _nameController,
                    placeholder: "Exercise Name",
                    padding: const EdgeInsets.all(12),
                    decoration: null,
                  ),
                ),

                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CupertinoColors.systemGrey4),
                  ),
                  child: CupertinoTextField(
                    controller: _descriptionController,
                    placeholder: "Description",
                    padding: const EdgeInsets.all(12),
                    maxLines: 3,
                    decoration: null,
                  ),
                ),

                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CupertinoColors.systemGrey4),
                  ),
                  child: CupertinoTextField(
                    controller: _categoryController,
                    placeholder: "Category (e.g., Strength, Cardio, Flexibility)",
                    padding: const EdgeInsets.all(12),
                    decoration: null,
                  ),
                ),

                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CupertinoColors.systemGrey4),
                  ),
                  child: CupertinoTextField(
                    controller: _musclesController,
                    placeholder: "Target Muscles (e.g., Chest, Back, Legs)",
                    padding: const EdgeInsets.all(12),
                    decoration: null,
                  ),
                ),

                const SizedBox(height: 24),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: kPrimaryBlue,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: _createExercise,
                  child: const Text(
                    "Create Exercise",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
