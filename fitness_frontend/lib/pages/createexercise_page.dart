import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateExercisePage extends StatefulWidget {
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
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = json.decode(response.body)['detail'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Exercise")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Exercise Name",
                  hintText: "Enter the name of the exercise",
                ),
              ),

              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Enter a description of the exercise",
                ),
              ),

              const SizedBox(height: 16),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: "Category",
                  hintText: "E.g., Strength, Cardio, Flexibility",
                ),
              ),

              const SizedBox(height: 16),
              TextField(
                controller: _musclesController,
                decoration: const InputDecoration(
                  labelText: "Target Muscles",
                  hintText: "E.g., Chest, Back, Legs",
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _createExercise,
                child: const Text("Create Exercise"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
